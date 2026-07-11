async function getAccessToken(env) {
	const header = { alg: "RS256", typ: "JWT" };
	const now = Math.floor(Date.now() / 1000);
	const claim = {
		iss: env.FIREBASE_CLIENT_EMAIL,
		scope: "https://www.googleapis.com/auth/firebase.messaging",
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

export default {
	async fetch(request, env) {
		if (request.method !== "POST") {
			return new Response("Method not allowed", { status: 405 });
		}

		// Check the shared secret so random requests can't spam this endpoint
		if (request.headers.get("X-Okaeri-Secret") !== env.SHARED_SECRET) {
			return new Response("Unauthorized", { status: 401 });
		}

		const { token, title, body } = await request.json();

		// Only token and title are required
		if (!token || !title) {
			return new Response("Missing required fields", { status: 400 });
		}

		const accessToken = await getAccessToken(env);

		// Build the notification payload
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
				body: JSON.stringify({
					message: {
						token,
						notification,
					},
				}),
			}
		);

		const result = await fcmRes.json();

		return new Response(JSON.stringify(result), {
			status: fcmRes.ok ? 200 : 500,
			headers: {
				"Content-Type": "application/json",
			},
		});
	},
};