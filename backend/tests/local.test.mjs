import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { deliverDueMessages } from '../functions/scheduled-messages.js';

const requireFunctions = createRequire(new URL('../functions/package.json', import.meta.url));
const { initializeApp, deleteApp } = requireFunctions('firebase-admin/app');
const { getFirestore } = requireFunctions('firebase-admin/firestore');

const authURL = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const dbURL = 'http://127.0.0.1:8080/v1/projects/demo-talkr/databases/(default)/documents';
const prefix = 'projects/demo-talkr/databases/(default)/documents';
const request = async (url, method, body, token) => {
  const response = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return { status: response.status, data: await response.json() };
};
const string = stringValue => ({ stringValue });
const strings = values => ({ arrayValue: { values: values.map(string) } });

async function account(number) {
  const sent = await request(`${authURL}/accounts:sendVerificationCode?key=local-demo-key`, 'POST', { phoneNumber: number });
  assert.equal(sent.status, 200);
  const codes = await (await fetch('http://127.0.0.1:9099/emulator/v1/projects/demo-talkr/verificationCodes')).json();
  const code = codes.verificationCodes.find(value => value.phoneNumber === number).code;
  const wrong = await request(`${authURL}/accounts:signInWithPhoneNumber?key=local-demo-key`, 'POST', { sessionInfo: sent.data.sessionInfo, code: code === '000000' ? '111111' : '000000' });
  assert.notEqual(wrong.status, 200, 'wrong OTP must not sign in');
  const signed = await request(`${authURL}/accounts:signInWithPhoneNumber?key=local-demo-key`, 'POST', { sessionInfo: sent.data.sessionInfo, code });
  assert.equal(signed.status, 200);
  return { id: signed.data.localId, token: signed.data.idToken };
}

test('phone OTP, two-user messages, read receipts, and isolation', async () => {
  const seed = Math.floor(Math.random() * 1000000).toString().padStart(6, '0');
  const users = [];
  const documents = [];
  try {
    for (const suffix of ['1','2','3']) users.push(await account(`+1555${seed}${suffix}`));
    const [alice,bob,stranger] = users;
    const roomID = [alice.id,bob.id].sort().join('_');
    const roomPath = `chats/${roomID}`;
    const messagePath = `${roomPath}/messages/test-message`;
    documents.push(roomPath, messagePath);
    const message = {
      id: string('test-message'), senderId: string(alice.id), content: string('Hello from Alice'),
      timestamp: { timestampValue: new Date().toISOString() },
      isIncoming: { booleanValue: false }, isRead: { booleanValue: false },
    };
    const commit = await request(`${dbURL}:commit`, 'POST', { writes: [
      { update: { name: `${prefix}/${roomPath}`, fields: { participants: strings([alice.id,bob.id].sort()), lastMessage: string('Hello from Alice') } } },
      { update: { name: `${prefix}/${messagePath}`, fields: message } },
    ] }, alice.token);
    assert.equal(commit.status, 200, JSON.stringify(commit.data));
    assert.equal((await request(`${dbURL}/${messagePath}`, 'GET', null, bob.token)).status, 200);
    assert.equal((await request(`${dbURL}/${messagePath}`, 'GET', null, stranger.token)).status, 403);
    assert.equal((await request(`${dbURL}/${messagePath}`, 'GET')).status, 403);
    const readBody = { fields: { isRead: { booleanValue: true } } };
    assert.equal((await request(`${dbURL}/${messagePath}?updateMask.fieldPaths=isRead`, 'PATCH', readBody, alice.token)).status, 403);
    assert.equal((await request(`${dbURL}/${messagePath}?updateMask.fieldPaths=isRead`, 'PATCH', readBody, bob.token)).status, 200);
    const spoof = await request(`${dbURL}/${roomPath}/messages/spoof`, 'PATCH', { fields: { ...message, senderId: string(bob.id) } }, alice.token);
    assert.equal(spoof.status, 403);
    const replyPath = `${roomPath}/messages/reply`;
    documents.push(replyPath);
    const reply = await request(`${dbURL}/${replyPath}`, 'PATCH', { fields: { ...message, senderId: string(bob.id), content: string('Reply from Bob') } }, bob.token);
    assert.equal(reply.status, 200);
    assert.equal((await request(`${dbURL}/${replyPath}`, 'GET', null, alice.token)).status, 200);
  } finally {
    for (const path of documents.reverse()) await request(`${dbURL}/${path}`, 'DELETE', null, 'owner');
    for (const user of users) await request(`${authURL}/accounts:delete?key=local-demo-key`, 'POST', { idToken: user.token });
  }
});

test('calling-token endpoint rejects requests without a Firebase login', async () => {
  const result = await request('http://127.0.0.1:5001/demo-talkr/us-central1/callingToken', 'POST', { data: { uid: 'someone-else' } });
  assert.equal(result.status, 401);
  assert.equal(result.data.error.status, 'UNAUTHENTICATED');
});

test('scheduled messages stay private, survive client logout, cancel, and deliver once', async () => {
  process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
  const app = initializeApp({ projectId: 'demo-talkr' }, 'schedule-tests');
  const db = getFirestore(app);
  const seed = Math.floor(Math.random() * 1000000).toString().padStart(6, '0');
  const users = [];
  const documents = [];
  try {
    for (const suffix of ['4', '5', '6']) users.push(await account(`+1555${seed}${suffix}`));
    const [alice, bob, stranger] = users;
    const roomID = [alice.id, bob.id].sort().join('_');
    const roomPath = `chats/${roomID}`;
    documents.push(roomPath);
    assert.equal((await request(`${dbURL}/${roomPath}`, 'PATCH', { fields: {
      participants: strings([alice.id, bob.id].sort()),
    } }, alice.token)).status, 200);
    // Restrict worker scans to this test room; never advance a user's real queue.
    const isolatedDB = {
      collection: name => name === 'scheduledMessages'
        ? db.collection(name).where('chatId', '==', roomID) : db.collection(name),
      runTransaction: callback => db.runTransaction(callback),
    };
    const date = new Date(Date.now() + 60000);
    const queueID = `test-${seed}`;
    const queuePath = `scheduledMessages/${queueID}`;
    documents.push(queuePath, `${roomPath}/messages/scheduled_${queueID}`);
    const fields = {
      id: string(queueID), chatId: string(roomID), senderId: string(alice.id),
      content: string('Send later from Alice'), scheduledFor: { timestampValue: date.toISOString() },
    };
    const create = await request(`${dbURL}/${queuePath}`, 'PATCH', { fields }, alice.token);
    assert.equal(create.status, 200, JSON.stringify(create.data));
    assert.equal((await request(`${dbURL}/${queuePath}`, 'GET', null, alice.token)).status, 200);
    for (const token of [bob.token, stranger.token, undefined]) {
      assert.equal((await request(`${dbURL}/${queuePath}`, 'GET', null, token)).status, 403);
      assert.equal((await request(`${dbURL}/${queuePath}`, 'DELETE', null, token)).status, 403);
    }
    // A second authenticated account cannot forge a sender or schedule into another room.
    assert.equal((await request(`${dbURL}/scheduledMessages/spoof-${seed}`, 'PATCH', {
      fields: { ...fields, id: string(`spoof-${seed}`) },
    }, bob.token)).status, 403);
    assert.equal((await request(`${dbURL}/scheduledMessages/stranger-${seed}`, 'PATCH', {
      fields: { ...fields, id: string(`stranger-${seed}`), senderId: string(stranger.id) },
    }, stranger.token)).status, 403);
    assert.equal((await request(`${dbURL}/scheduledMessages/past-${seed}`, 'PATCH', {
      fields: { ...fields, id: string(`past-${seed}`), scheduledFor: { timestampValue: new Date(0).toISOString() } },
    }, alice.token)).status, 403);
    await deliverDueMessages(isolatedDB);
    assert.equal((await db.doc(`${roomPath}/messages/scheduled_${queueID}`).get()).exists, false, 'must not send early');

    const cancelledID = `cancel-${seed}`;
    const cancelledPath = `scheduledMessages/${cancelledID}`;
    documents.push(cancelledPath);
    assert.equal((await request(`${dbURL}/${cancelledPath}`, 'PATCH', {
      fields: { ...fields, id: string(cancelledID) },
    }, alice.token)).status, 200);
    assert.equal((await request(`${dbURL}/${cancelledPath}`, 'DELETE', null, alice.token)).status, 200);
    // No client timer/auth session is involved. Advance the worker clock in this test.
    await Promise.all([deliverDueMessages(isolatedDB, date), deliverDueMessages(isolatedDB, date)]);
    await deliverDueMessages(isolatedDB, date);
    const delivered = await db.doc(`${roomPath}/messages/scheduled_${queueID}`).get();
    assert.equal(delivered.data().senderId, alice.id);
    assert.equal(delivered.data().content, fields.content.stringValue);
    assert.equal((await db.collection(`${roomPath}/messages`).get()).size, 1);
    assert.equal((await db.doc(queuePath).get()).exists, false);
    assert.deepEqual((await db.doc(roomPath).get()).data().unreadFor, [bob.id]);
    assert.equal((await request(`${dbURL}/${roomPath}/messages/scheduled_${queueID}`, 'GET', null, bob.token)).status, 200);
  } finally {
    for (const path of documents.reverse()) await request(`${dbURL}/${path}`, 'DELETE', null, 'owner');
    for (const user of users) await request(`${authURL}/accounts:delete?key=local-demo-key`, 'POST', { idToken: user.token });
    await db.terminate();
    await deleteApp(app);
  }
});
