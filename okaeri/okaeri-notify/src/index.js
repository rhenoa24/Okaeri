async function getAccessToken(env, scope) {
	const header = { alg: "RS256", typ: "JWT" };
	const now = Math.floor(Date.now() / 1000);
	const claim = {
		iss: env.FIREBASE_CLIENT_EMAIL,
		scope,
		aud: "https://oauth2.googleapis.com/token",
		exp: now + 3600,
		iat: now,
	};

	const encode = (obj) =>
		btoa(JSON.stringify(obj))
			.replace(/=/g, "")
			.replace(/\+/g, "-")
			.replace(/\//g, "_");

	const unsigned = `${encode(header)}.${encode(claim)}`;

	const pemKey = env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n");
	const pemContents = pemKey
		.replace("-----BEGIN PRIVATE KEY-----", "")
		.replace("-----END PRIVATE KEY-----", "")
		.replace(/\s/g, "");
	const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

	const cryptoKey = await crypto.subtle.importKey(
		"pkcs8",
		binaryKey,
		{ name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
		false,
		["sign"]
	);

	const signature = await crypto.subtle.sign(
		"RSASSA-PKCS1-v1_5",
		cryptoKey,
		new TextEncoder().encode(unsigned)
	);

	const encodedSig = btoa(String.fromCharCode(...new Uint8Array(signature)))
		.replace(/=/g, "")
		.replace(/\+/g, "-")
		.replace(/\//g, "_");

	const jwt = `${unsigned}.${encodedSig}`;

	const res = await fetch("https://oauth2.googleapis.com/token", {
		method: "POST",
		headers: { "Content-Type": "application/x-www-form-urlencoded" },
		body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
	});

	const data = await res.json();
	return data.access_token;
}

async function sendFcm(env, accessToken, token, title, body) {
	const notification = { title };
	if (body && body.trim().length > 0) {
		notification.body = body;
	}

	const fcmRes = await fetch(
		`https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`,
		{
			method: "POST",
			headers: {
				Authorization: `Bearer ${accessToken}`,
				"Content-Type": "application/json",
			},
			body: JSON.stringify({ message: { token, notification } }),
		}
	);

	if (!fcmRes.ok) {
		console.error("FCM send failed:", await fcmRes.text());
	}
	return fcmRes.ok;
}

// ---------------------------------------------------------------------
// Date helpers
// ---------------------------------------------------------------------

function dateStr(d) {
	return d.toISOString().slice(0, 10);
}

function addDays(d, n) {
	const copy = new Date(d);
	copy.setUTCDate(copy.getUTCDate() + n);
	return copy;
}

// Mirrors CalendarNote.nextOccurrence(): same-day still counts as
// occurring today (not pushed to next year) since the comparison is
// strictly-less-than. Relies on the cron firing at a UTC time that's
// safely inside the same calendar day in Manila — see wrangler config.
function nextOccurrenceStr(storedDateStr, today) {
	const [, month, day] = storedDateStr.split("-").map(Number);
	let occ = new Date(Date.UTC(today.getUTCFullYear(), month - 1, day));
	if (occ < today) {
		occ = new Date(Date.UTC(today.getUTCFullYear() + 1, month - 1, day));
	}
	return dateStr(occ);
}

// Mirrors _PlanPreviewRow._displayTime in home_screen.dart: earliest
// timetable entry, formatted as 12-hour time.
function earliestTimeLabel(planFields) {
	const entries = planFields.timetable?.arrayValue?.values ?? [];
	const times = entries
		.map((v) => v.mapValue?.fields?.time?.stringValue)
		.filter(Boolean)
		.sort();
	if (times.length === 0) return null;

	const [hourStr, minute] = times[0].split(":");
	const hour = parseInt(hourStr, 10);
	const period = hour >= 12 ? "PM" : "AM";
	const hour12 = hour % 12 === 0 ? 12 : hour % 12;
	return `${hour12}:${minute} ${period}`;
}

// ---------------------------------------------------------------------
// Firestore
// ---------------------------------------------------------------------

async function runCollectionGroupQuery(env, accessToken, collectionId, filters) {
	const url = `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery`;

	const structuredQuery = { from: [{ collectionId, allDescendants: true }] };
	if (filters && filters.length > 0) {
		structuredQuery.where =
			filters.length === 1
				? { fieldFilter: filters[0] }
				: { compositeFilter: { op: "AND", filters: filters.map((f) => ({ fieldFilter: f })) } };
	}

	const res = await fetch(url, {
		method: "POST",
		headers: {
			Authorization: `Bearer ${accessToken}`,
			"Content-Type": "application/json",
		},
		body: JSON.stringify({ structuredQuery }),
	});

	if (!res.ok) {
		console.error(`Firestore query for ${collectionId} failed:`, await res.text());
		return [];
	}

	const rows = await res.json();
	return rows
		.filter((r) => r.document)
		.map((r) => {
			const doc = r.document;
			const path = doc.name.split("/documents/")[1];
			const coupleId = path.split("/")[1];
			return { path, coupleId, fields: doc.fields ?? {} };
		});
}

async function getCoupleMemberIds(env, accessToken, coupleId) {
	const url = `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/couples/${coupleId}`;
	const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
	if (!res.ok) return [];
	const doc = await res.json();
	const members = doc.fields?.members?.arrayValue?.values ?? [];
	return members.map((v) => v.stringValue).filter(Boolean);
}

async function getFcmToken(env, accessToken, uid) {
	const url = `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/users/${uid}`;
	const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
	if (!res.ok) return null;
	const doc = await res.json();
	return doc.fields?.fcmToken?.stringValue ?? null;
}

async function patchField(env, accessToken, path, fieldName, value) {
	const url = `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${path}?updateMask.fieldPaths=${fieldName}`;
	await fetch(url, {
		method: "PATCH",
		headers: {
			Authorization: `Bearer ${accessToken}`,
			"Content-Type": "application/json",
		},
		body: JSON.stringify({ fields: { [fieldName]: { stringValue: value } } }),
	});
}

async function patchIntField(env, accessToken, path, fieldName, value) {
	const url = `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${path}?updateMask.fieldPaths=${fieldName}`;
	await fetch(url, {
		method: "PATCH",
		headers: {
			Authorization: `Bearer ${accessToken}`,
			"Content-Type": "application/json",
		},
		body: JSON.stringify({ fields: { [fieldName]: { integerValue: String(value) } } }),
	});
}

async function notifyCouple(env, accessToken, coupleId, title, body) {
	const memberIds = await getCoupleMemberIds(env, accessToken, coupleId);
	const tokens = (
		await Promise.all(memberIds.map((uid) => getFcmToken(env, accessToken, uid)))
	).filter(Boolean);
	await Promise.all(tokens.map((t) => sendFcm(env, accessToken, t, title, body)));
}

async function maybeRemind(env, accessToken, item, occ, todayStr, tomorrowStr, kind) {
	const title = item.fields.title?.stringValue ?? (kind === "plan" ? "Your plan" : "Your date");
	const timeLabel = kind === "plan" ? earliestTimeLabel(item.fields) : null;

	if (occ === tomorrowStr && item.fields.remindedTomorrowFor?.stringValue !== occ) {
		const body =
			kind === "plan"
				? timeLabel
					? `Tomorrow at ${timeLabel}.`
					: "You have plans together tomorrow."
				: "Something special is coming up tomorrow.";
		await notifyCouple(env, accessToken, item.coupleId, `Tomorrow: ${title} 💌`, body);
		await patchField(env, accessToken, item.path, "remindedTomorrowFor", occ);
	}
	if (occ === todayStr && item.fields.remindedTodayFor?.stringValue !== occ) {
		const body =
			kind === "plan" && timeLabel
				? `Enjoy your day together! Starting at ${timeLabel}.`
				: "Enjoy your day together!";
		await notifyCouple(env, accessToken, item.coupleId, `Today: ${title} 💌`, body);
		await patchField(env, accessToken, item.path, "remindedTodayFor", occ);
	}
}

// ---------------------------------------------------------------------
// Period tracker reminders
// ---------------------------------------------------------------------

// Ongoing periods: a daily "Day X of period" nudge. Day 1 is skipped —
// the app already sends an immediate push the moment a period is logged
// as started (see period_service.dart), so the cron picks up from Day 2.
async function checkOngoingPeriods(env, accessToken, today) {
	const ongoing = await runCollectionGroupQuery(env, accessToken, "periodTracker", [
		{ field: { fieldPath: "endDate" }, op: "EQUAL", value: { nullValue: null } },
	]);

	for (const entry of ongoing) {
		const startStr = entry.fields.startDate?.stringValue;
		if (!startStr) continue;

		const start = new Date(startStr + "T00:00:00Z");
		const day = Math.floor((today - start) / 86400000) + 1;
		if (day < 2) continue;

		const remindedDay = entry.fields.remindedDayNumber?.integerValue
			? parseInt(entry.fields.remindedDayNumber.integerValue, 10)
			: null;
		if (remindedDay === day) continue;

		await notifyCouple(
			env,
			accessToken,
			entry.coupleId,
			`Day ${day} of period 🩸`,
			"A little extra patience and comfort go a long way today."
		);
		await patchIntField(env, accessToken, entry.path, "remindedDayNumber", day);
	}
}

// Predicted next period, one day out — projected from each couple's most
// recently logged period start plus their configured average cycle length
// (couples/{coupleId}/meta/periodSettings), mirroring PeriodService's
// predictNextPeriod() on the client.
async function checkPredictedPeriods(env, accessToken, tomorrowStr) {
	const allEntries = await runCollectionGroupQuery(env, accessToken, "periodTracker", []);

	const latestByCouple = {};
	for (const entry of allEntries) {
		const startStr = entry.fields.startDate?.stringValue;
		if (!startStr) continue;
		const existing = latestByCouple[entry.coupleId];
		if (!existing || startStr > existing.startStr) {
			latestByCouple[entry.coupleId] = { startStr };
		}
	}

	for (const [coupleId, info] of Object.entries(latestByCouple)) {
		const settingsUrl = `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/couples/${coupleId}/meta/periodSettings`;
		const settingsRes = await fetch(settingsUrl, {
			headers: { Authorization: `Bearer ${accessToken}` },
		});
		const settingsDoc = settingsRes.ok ? await settingsRes.json() : null;

		const avgCycleLength = settingsDoc?.fields?.avgCycleLength?.integerValue
			? parseInt(settingsDoc.fields.avgCycleLength.integerValue, 10)
			: 28;
		const alreadyRemindedFor = settingsDoc?.fields?.remindedPredictionFor?.stringValue;

		const lastStart = new Date(info.startStr + "T00:00:00Z");
		const predicted = addDays(lastStart, avgCycleLength);
		const predictedStr = dateStr(predicted);

		if (predictedStr === tomorrowStr && alreadyRemindedFor !== predictedStr) {
			await notifyCouple(
				env,
				accessToken,
				coupleId,
				"Period expected tomorrow 🩷",
				"Just a heads up — might be worth stocking up on essentials."
			);
			await patchField(
				env,
				accessToken,
				`couples/${coupleId}/meta/periodSettings`,
				"remindedPredictionFor",
				predictedStr
			);
		}
	}
}

// ---------------------------------------------------------------------
// The daily sweep
// ---------------------------------------------------------------------

async function checkReminders(env) {
	const accessToken = await getAccessToken(
		env,
		"https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging"
	);

	const today = new Date(new Date().toISOString().slice(0, 10));
	const todayStr = dateStr(today);
	const tomorrowStr = dateStr(addDays(today, 1));

	// Plans: one-off, only reads today-or-later (composite index required —
	// see wrangler notes / first-run error link).
	const plans = await runCollectionGroupQuery(env, accessToken, "plans", [
		{ field: { fieldPath: "date" }, op: "GREATER_THAN_OR_EQUAL", value: { stringValue: todayStr } },
	]);
	for (const plan of plans) {
		const occ = plan.fields.date?.stringValue;
		if (!occ) continue;
		await maybeRemind(env, accessToken, plan, occ, todayStr, tomorrowStr, "plan");
	}

	// Events, non-repeating: same date filter as plans.
	const oneOffNotes = await runCollectionGroupQuery(env, accessToken, "calendarNotes", [
		{ field: { fieldPath: "isRepeating" }, op: "EQUAL", value: { booleanValue: false } },
		{ field: { fieldPath: "date" }, op: "GREATER_THAN_OR_EQUAL", value: { stringValue: todayStr } },
	]);
	for (const note of oneOffNotes) {
		const occ = note.fields.date?.stringValue;
		if (!occ) continue;
		await maybeRemind(env, accessToken, note, occ, todayStr, tomorrowStr, "event");
	}

	// Events, repeating: full read, occurrence computed in JS.
	const repeatingNotes = await runCollectionGroupQuery(env, accessToken, "calendarNotes", [
		{ field: { fieldPath: "isRepeating" }, op: "EQUAL", value: { booleanValue: true } },
	]);
	for (const note of repeatingNotes) {
		const stored = note.fields.date?.stringValue;
		if (!stored) continue;
		const occ = nextOccurrenceStr(stored, today);
		await maybeRemind(env, accessToken, note, occ, todayStr, tomorrowStr, "event");
	}

	// Period tracker: ongoing "Day X" nudges + "period expected tomorrow".
	await checkOngoingPeriods(env, accessToken, today);
	await checkPredictedPeriods(env, accessToken, tomorrowStr);
}

export default {
	async fetch(request, env) {
		if (request.method !== "POST") {
			return new Response("Method not allowed", { status: 405 });
		}

		if (request.headers.get("X-Okaeri-Secret") !== env.SHARED_SECRET) {
			return new Response("Unauthorized", { status: 401 });
		}

		const { token, title, body } = await request.json();

		if (!token || !title) {
			return new Response("Missing required fields", { status: 400 });
		}

		const accessToken = await getAccessToken(env, "https://www.googleapis.com/auth/firebase.messaging");
		const notification = { title };
		if (body && body.trim().length > 0) {
			notification.body = body;
		}

		const fcmRes = await fetch(
			`https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`,
			{
				method: "POST",
				headers: {
					Authorization: `Bearer ${accessToken}`,
					"Content-Type": "application/json",
				},
				body: JSON.stringify({ message: { token, notification } }),
			}
		);

		const result = await fcmRes.json();

		return new Response(JSON.stringify(result), {
			status: fcmRes.ok ? 200 : 500,
			headers: { "Content-Type": "application/json" },
		});
	},

	async scheduled(event, env, ctx) {
		ctx.waitUntil(checkReminders(env));
	},
};