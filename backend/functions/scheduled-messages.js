import { FieldValue, Timestamp } from 'firebase-admin/firestore';

// The queue entry and delivered message change together. Retrying this transaction
// (or running two workers) cannot deliver the same queued message twice.
export async function deliverDueMessages(db, now = new Date()) {
  const due = await db.collection('scheduledMessages')
    .where('scheduledFor', '<=', Timestamp.fromDate(now)).limit(100).get();
  for (const candidate of due.docs) {
    await db.runTransaction(async transaction => {
      const queued = await transaction.get(candidate.ref);
      if (!queued.exists) return; // Cancelled or already delivered.
      const message = queued.data();
      if (message.scheduledFor.toMillis() > now.getTime()) return;
      const roomRef = db.collection('chats').doc(message.chatId);
      const room = await transaction.get(roomRef);
      if (!room.exists || !room.data().participants.includes(message.senderId)) return;
      const recipient = room.data().participants.find(id => id !== message.senderId);
      const id = `scheduled_${queued.id}`;
      transaction.create(roomRef.collection('messages').doc(id), {
        id, senderId: message.senderId, content: message.content,
        timestamp: FieldValue.serverTimestamp(), isIncoming: false, isRead: false,
      });
      transaction.update(roomRef, {
        lastMessage: message.content, updatedAt: FieldValue.serverTimestamp(),
        unreadFor: [recipient],
      });
      transaction.delete(candidate.ref);
    });
  }
  return due.size;
}
