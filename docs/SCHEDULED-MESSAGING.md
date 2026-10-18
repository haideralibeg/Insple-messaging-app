# Scheduled messages — local integration

> Checkpoint: the owner subsequently authorized committing and pushing this work to a new feature branch. Earlier no-push statements below describe the implementation period. Main remains untouched. See PROGRESS.md for the saved status.
## Where the feature came from

Fetched GitHub branch [`scheduleMessageUpdate`](https://github.com/haideralibeg/Insple-messaging-app/tree/scheduleMessageUpdate), commit `c3c04f15fe303c4af8a861e296299b170f7139a5`, for comparison. The working branch remains `nostalgic`. No merge, commit, push, or deployment was performed, and `main` was not changed.

That branch introduces a clock button, a date/time picker, and pending messages in Gen Z. It also includes older login, theme, and message-store changes. Those files were not copied over wholesale because that would overwrite the working local phone login and Nostalgic interface.

The scheduling workflow has been adapted into the current app. The original in-memory timer was replaced: it lost messages when the app closed and used whichever account was signed in when the timer fired.

## How to try it

Keep the Firebase emulators running as described in LOCAL-TESTING.md. In another terminal, from the project folder:

```sh
cd backend
npm run scheduler
```

Use **Talkr Local** on both simulators:

1. Open a conversation and type a message.
2. In **Gen Z**, tap the clock beside the message field. In **Nostalgic**, tap **Send later**.
3. Choose a date/time, or tap **In 1 minute** for a quick test.
4. Tap **Schedule message**. The draft clears only after the local service confirms saving it.
5. The sender sees a separate scheduled entry with its delivery time. The recipient cannot see it yet.
6. Use **Cancel scheduled message** to remove a queued message. Cancellation and delivery are serialized: if delivery has already won the race, cancellation cannot recall the sent message.
7. At the scheduled time, the worker converts the queue entry into a normal message and updates the inbox and unread indicator. Normal read receipts apply.

Theme switching does not change the queue. Leaving the conversation, closing the app, or signing out does not cancel a saved message: it still sends as its original sender. Cancel it explicitly before signing out if you no longer want it sent.

## What runs where

- `Talkr/ScheduledMessages.swift`: shared date picker, pending rows, cancellation, and sender-only queue listener.
- `Talkr/ChatView.swift`: Gen Z clock and shared schedule sheet.
- `Talkr/NostalgicMode.swift`: retro Send later button and scheduled entries.
- `Talkr/ContentView.swift`: resets the visible queue when accounts change.
- `backend/firestore.rules`: only the sender can create/read/cancel their queue entries; the sender must belong to the conversation.
- `backend/functions/scheduled-messages.js`: atomic delivery. Repeated or concurrent worker attempts cannot deliver a queue entry twice.
- `backend/functions/local-scheduler.js`: checks once per second and is hardcoded to the Mac's demo emulator. No live service credentials are used.

## Local limits and the path to main

Both the emulators and the scheduler must be running on the Mac. If the scheduler stops, messages wait and are sent when it restarts. Timing is best effort, normally within a few seconds. Closing a simulator app is fine. Restarting the emulators clears their temporary data, including queued messages, unless export/import is configured.

Scheduling controls are enabled only in Talkr Local for now, so the normal app cannot silently queue messages without a deployed delivery service. Before enabling live scheduling, a hosted scheduler, reviewed production access rules, monitoring, and production tests are still needed. These require a separate authorized deployment. Making this version main remains a later user-approved step.

## Validation

- Xcode build passed (`BUILD SUCCEEDED`).
- Emulator checks cover future-time validation, private queue visibility, ownership, blocked sender impersonation, blocked outsiders, cancellation, no early delivery, recipient visibility after delivery, inbox unread state, and duplicate-worker/retry protection.
- Simulator checks passed: Nostalgic scheduled a one-minute message; the pending entry stayed visible after switching to Gen Z; the recipient received the message while the sender app was inactive. Gen Z scheduling and cancellation passed, and ordinary messaging still worked. No overlapping or cropped controls were observed. A separate one-minute send from Gen Z also passed: the recipient could not see it early, received it at the scheduled time, and the sender saw a normal message with seen status. Device-control sessions have ended.

## Implementation references

- [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions): queue removal, message creation, and inbox updates succeed together.
- [SwiftUI DatePicker](https://developer.apple.com/documentation/swiftui/datepicker): the schedule sheet uses the system date and time picker.

Final build after all edits passed. All three backend tests passed. Custom date-picker selection, an exact cancellation/delivery race through the UI, offline errors, and production scheduling were not exercised in simulator testing.
