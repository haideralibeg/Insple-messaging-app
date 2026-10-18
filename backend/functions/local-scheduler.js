import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { setTimeout } from 'node:timers/promises';
import { deliverDueMessages } from './scheduled-messages.js';

// Hardcoded emulator target: this local worker must never access a live project.
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
const app = initializeApp({ projectId: 'demo-talkr' }, 'local-scheduler');
const db = getFirestore(app);
console.log('Talkr scheduled messages: local emulator only, checking every second.');
while (true) {
  try { await deliverDueMessages(db); }
  catch (error) { console.error('Scheduled delivery will retry:', error.message); }
  await setTimeout(1000);
}
