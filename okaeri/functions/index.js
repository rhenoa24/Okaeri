const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendLoveLetterNotification = onDocumentCreated(
    "couples/{coupleId}/loveLetters/{letterId}",
    async (event) => {
        const data = event.data?.data();

        if (!data) return;

        const coupleId = event.params.coupleId;
        const letterId = event.params.letterId;
        const senderId = data.senderId;

        // Get couple members
        const coupleDoc = await admin
            .firestore()
            .collection("couples")
            .doc(coupleId)
            .get();

        if (!coupleDoc.exists) return;

        const members = coupleDoc.data().members || [];

        // Find the receiver (the other partner)
        const receiverId = members.find((uid) => uid !== senderId);

        if (!receiverId) return;

        // Get receiver's FCM token
        const receiverDoc = await admin
            .firestore()
            .collection("users")
            .doc(receiverId)
            .get();

        if (!receiverDoc.exists) return;

        const token = receiverDoc.data().fcmToken;

        if (!token) return;

        // Get sender's display name
        const senderDoc = await admin
            .firestore()
            .collection("users")
            .doc(senderId)
            .get();

        const senderName =
            senderDoc.exists
                ? senderDoc.data().displayName || "Someone"
                : "Someone";

        // Build preview
        const content = (data.content || "").trim();

        const preview =
            content.length > 120
                ? content.substring(0, 120) + "..."
                : content;

        // Send notification
        await admin.messaging().send({
            token,
            notification: {
                title: `💌 ${senderName} sent you a love letter`,
                body: preview,
            },
            data: {
                screen: "love_letter",
                coupleId,
                letterId,
            },
        });

        console.log(`Notification sent to ${receiverId}`);
    }
);