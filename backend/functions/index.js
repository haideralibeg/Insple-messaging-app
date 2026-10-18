import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { StreamClient } from '@stream-io/node-sdk';

initializeApp();
const streamKey = defineSecret('STREAM_API_KEY');
const streamSecret = defineSecret('STREAM_API_SECRET');

export const callingToken = onCall({
  secrets: [streamKey, streamSecret],
  enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== 'true',
  maxInstances: 5,
}, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const apiKey = streamKey.value();
  const secret = streamSecret.value();
  if (!apiKey || !secret || apiKey === 'not-configured' || secret === 'not-configured') {
    throw new HttpsError('failed-precondition', 'Calling is not configured yet.');
  }
  // Never accept the caller identity, display name, or role from request.data.
  const user = await getAuth().getUser(request.auth.uid);
  if (user.disabled) throw new HttpsError('permission-denied', 'Account disabled.');
  const client = new StreamClient(apiKey, secret);
  await client.upsertUsers([{ id: user.uid, name: user.displayName || 'Talkr user', role: 'user' }]);
  return {
    apiKey,
    token: client.generateUserToken({ user_id: user.uid, validity_in_seconds: 3600 }),
  };
});
