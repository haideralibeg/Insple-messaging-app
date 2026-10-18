# Talkr progress checkpoint — October 18, 2026

The owner requested saving all current work and pushing a new branch. No merge into main, deployment, or billing activation is authorized by this checkpoint.

## Working and verified locally

- Phone authentication with two test accounts, generated emulator codes, and separate Talkr Local app identity.
- Two-account messaging, inbox updates, read receipts, and existing Gen Z / Nostalgic interfaces.
- Scheduled messages adapted from scheduleMessageUpdate, with controls in both themes, private persistent queue, cancellation, and a local delivery worker.
- Timed delivery from both themes; sender app inactive during delivery; cancellation; normal messaging after scheduling.
- Xcode local build passed. Three emulator backend tests passed, including permissions and duplicate-delivery checks.

## Present but awaiting setup or verification

- Stream voice/video SDK and call buttons are integrated; actual audio/video needs Stream credentials and device testing.
- Background incoming calls need Apple push configuration and physical-device verification.
- Normal Talkr uses live Firebase. Phone provider is enabled and US-only SMS access was configured. Billing is disabled, and the owner has paused it. No real SMS test has been completed.
- An explicit live Talkr scheme was added; Xcode needs to refresh its scheme list. Its live build and SMS flow still need verification.
- Scheduled delivery currently works only in Talkr Local with both emulators and the scheduler running. A hosted worker is not deployed.
- Call history, message push notifications, and private phone-contact matching remain unfinished.

## Running locally

Follow [LOCAL-TESTING.md](LOCAL-TESTING.md). Run `npm start` in backend for the emulators and `npm run scheduler` in a second terminal there. Use Talkr Local on two simulators. Emulator data is temporary unless exported; Git saves source/configuration, not simulator accounts or conversations.

Private credentials, Firebase CLI login tokens, debug logs, dependencies, and simulator data are excluded from the commit. The existing tracked Firebase client configuration remains in place; Stream server secrets belong only in the ignored backend/functions/.secret.local file.

## Voice/video recommendation

**Keep Stream Video for the next milestone.** The integration already exists, so it requires less implementation work than switching providers. Its [iOS SDK](https://getstream.io/video/docs/ios/) supplies SwiftUI calling components. Next: configure a development Stream app, add server credentials locally, then test calling between two devices. Custom Nostalgic call-screen styling is separate from the existing chat themes.

| Service | Why consider it | Tradeoff for Talkr |
| --- | --- | --- |
| [Stream Video](https://getstream.io/video/docs/ios/) | Existing integration and SwiftUI components | Hosted service usage costs; credentials and call testing still required |
| [LiveKit](https://docs.livekit.io/transport/sdk-platforms/swift/) | Swift SDK and an option to [self-host](https://docs.livekit.io/transport/self-hosting/) | Replacing the current calling integration; operating servers if self-hosted |
| [Agora](https://www.agora.io/en/products/video-call/) | Managed voice/video service with broad platform support | New integration and additional Talkr UI/call-flow work |

Compare real usage before selecting on price: a ten-minute two-person call consumes twenty participant-minutes. Video resolution, bandwidth, recordings, and plan terms can affect the bill. Current vendor references: [Stream pricing](https://getstream.io/video/pricing/), [LiveKit pricing](https://livekit.com/pricing), [Agora pricing](https://www.agora.io/en/pricing/). No subscription or service migration was performed.
