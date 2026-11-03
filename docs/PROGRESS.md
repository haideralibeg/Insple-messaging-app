# Talkr progress checkpoint — October 18, 2026

The owner requested saving all current work and pushing a new branch. No merge into main, deployment, or billing activation is authorized by this checkpoint.

## Working and verified locally

- Phone authentication with two test accounts, generated emulator codes, and separate Talkr Local app identity.
- Two-account messaging, inbox updates, read receipts, and existing Gen Z / Nostalgic interfaces.
- Scheduled messages adapted from scheduleMessageUpdate, with controls in both themes, private persistent queue, cancellation, and a local delivery worker.
- Timed delivery from both themes; sender app inactive during delivery; cancellation; normal messaging after scheduling.
- Xcode local build passed. Three emulator backend tests passed, including permissions and duplicate-delivery checks.

## Present but awaiting setup or verification

- Stream credentials are now validated. Simulator ringing, answering, and two-participant joining work; actual microphone/camera media still needs physical-device testing.
- Background incoming calls need Apple push configuration and physical-device verification.
- Normal Talkr uses live Firebase. Phone provider is enabled and US-only SMS access was configured. Billing is disabled, and the owner has paused it. No real SMS test has been completed.
- An explicit live Talkr scheme was added; Xcode needs to refresh its scheme list. Its live build and SMS flow still need verification.
- Scheduled delivery currently works only in Talkr Local with both emulators and the scheduler running. A hosted worker is not deployed.
- Call history, message push notifications, and private phone-contact matching remain unfinished.

## Running locally

Follow [LOCAL-TESTING.md](LOCAL-TESTING.md). Run `npm start` in backend for the emulators and `npm run scheduler` in a second terminal there. Use Talkr Local on two simulators. Emulator data is temporary unless exported; Git saves source/configuration, not simulator accounts or conversations.

Private credentials, Firebase CLI login tokens, debug logs, dependencies, and simulator data are excluded from the commit. The existing tracked Firebase client configuration remains in place; Stream server secrets belong only in the ignored backend/functions/.secret.local file.

## Voice/video recommendation

**Keep Stream Video for the next milestone.** The integration already exists, so it requires less implementation work than switching providers. Its [iOS SDK](https://getstream.io/video/docs/ios/) supplies SwiftUI calling components. The development credentials are now saved locally and validated. Next: restrict call access to invited members and test microphone/camera media between two physical devices. Custom Nostalgic call-screen styling is separate from the existing chat themes.

| Service | Why consider it | Tradeoff for Talkr |
| --- | --- | --- |
| [Stream Video](https://getstream.io/video/docs/ios/) | Existing integration and SwiftUI components | Hosted service usage costs; physical-device media testing still required |
| [LiveKit](https://docs.livekit.io/transport/sdk-platforms/swift/) | Swift SDK and an option to [self-host](https://docs.livekit.io/transport/self-hosting/) | Replacing the current calling integration; operating servers if self-hosted |
| [Agora](https://www.agora.io/en/products/video-call/) | Managed voice/video service with broad platform support | New integration and additional Talkr UI/call-flow work |

Compare real usage before selecting on price: a ten-minute two-person call consumes twenty participant-minutes. Video resolution, bandwidth, recordings, and plan terms can affect the bill. Current vendor references: [Stream pricing](https://getstream.io/video/pricing/), [LiveKit pricing](https://livekit.com/pricing), [Agora pricing](https://www.agora.io/en/pricing/). No subscription or service migration was performed.

## Local integration from main — November 2, 2026

Adapted existing repository changes from main at f86ff9d into the current feature branch working copy. No new branch, commit, push, merge into main, or unrelated feature was created. Existing uncommitted local-testing notes were preserved.

Imported the profile/photo-picker screen, inbox and contacts navigation improvements, SwiftUI preview support, onboarding artwork, user manual, and screenshots. Preview support uses isolated sample state so rendering a canvas does not connect to Firebase or Stream. The profile now contains the existing Add phone number action, while sign-out is inside the profile screen. Phone login uses the same upstream logo as email login.

Kept our current phone authentication, emulator configuration, participant-based inbox listener, read receipts, persistent scheduled queue, and Stream calling service. Main's alternative chat-discovery listeners were not layered on top of these. Its voice/video CallView file is included for design previews; it remains presentation-only upstream, so actual app call buttons continue to use Stream. Profile photos, display-name edits, and privacy/blocking selections remain preview-only; no photo storage or access-policy backend was invented. A visible note identifies the unfinished privacy controls.

Validation: initial integrated local build succeeded. Backend and device regression checks are recorded after completion below.

### Verification after integration

The final integrated Xcode build succeeded, and all three emulator backend tests passed. Two simulators verified two-way messaging, seen status, scheduling and cancellation in both themes, profile navigation, photo-picker preview/removal, phone-link sheet, sign-out, and helper login.

Both locally saved Stream credentials were validated without printing them. The secret file is ignored by Git. Voice and video buttons rang the other simulator and both accounts joined a call. Actual audible sound and camera frames were not verified: the simulator camera remained off. Existing Stream automatic-leave policy was enabled after testing found that hanging up left the other person alone in the call; the retest result follows below.

Stream's default call type still permits broader user/guest joining. Member-only permissions must be configured before wider testing; no dashboard permissions or billing settings were changed. Background call notifications still need Apple/Stream push setup and real devices. Code remains local; nothing was committed or pushed.

Final hang-up retest passed in both directions: after an answered two-person call, the caller hung up and the other simulator returned to chat within three seconds. The final Xcode build and whitespace check passed.

Personal-team device signing: Talkr Local no longer requests the APNs entitlement, and local calling skips incoming push registration. This permits foreground call testing without paid push capability; keep both apps open. Live build entitlements remain unchanged. Physical-device networking still needs configuration.

## Physical iPhone connection — November 2

Fixed the phone login network error: simulators keep using 127.0.0.1, while physical Talkr Local builds read TalkrEmulatorHost from Configuration/LocalInfo.plist (currently 10.0.0.15). Authentication, Firestore, Functions and Fill test code all use this address. Added the local-network permission explanation and local HTTP allowance only to the local plist. The iPhone build passed.

A temporary TCP bridge on this Mac forwards Wi-Fi ports 9099, 8080 and 5001 to the existing loopback emulators, preserving accounts/messages without restarting them. This bridge must remain running for phone testing; it is not a deployed backend or a permanent startup service. If the Mac's Wi-Fi address changes, update TalkrEmulatorHost and restart the bridge. Use a trusted Wi-Fi network shared by the phone and Mac. No router port forwarding is needed. Emulator services are development-only and have no production authentication protection.

Run Talkr Local again on the iPhone to install these changes, allow Local Network access, choose Test account 1, then Send verification code → Fill test code → Verify. Use Test account 2 on the simulator. No real SMS is sent. Phone-side reachability and permissions must still be confirmed by the user; Mac-side checks can only verify the bridge itself.

## Chat keyboard fix — November 2

User confirmed voice and video work with their real iPhone and Mac. Both Gen Z and Nostalgic message lists now support dragging to dismiss the keyboard. Both composers share explicit SwiftUI focus state, which the phone/video buttons clear before starting a call. Draft text is preserved. The iPhone build passed; swipe and call-transition behavior still needs a hands-on check on the updated phone app. No push or commit was made.
