# Talkr: local phone login and calling work

> Checkpoint: the owner subsequently authorized committing and pushing this work to a new feature branch. Earlier no-push statements below describe the implementation period. Main remains untouched. See PROGRESS.md for the saved status.
This guide explains the changes in plain language. The test results section below distinguishes verified behavior from features that still need service setup.

## What stays the same

Your Gen Z and Nostalgic chat designs, messages, sounds, and theme switching remain in place. Messages travel over the internet, using either Wi-Fi or mobile data. They are not carrier SMS messages.

No commits, pushes, GitHub changes, cloud deployments, or live service configuration changes have been made.

## What changed

- **Scheduled messages:** Gen Z has a clock button; Nostalgic has Send later. See [SCHEDULED-MESSAGING.md](SCHEDULED-MESSAGING.md) for local setup, tests, and delivery limits. The local scheduler must also be running.

- **Phone sign-in:** The opening screen now asks for a number with a country code. Firebase sends a verification code and checks the code before signing the person in. The local emulator prints a test code instead of sending an SMS.
- **Existing accounts:** Email sign-in remains available. An existing user can sign in with email, press and hold their profile circle, and choose “Add phone number.” This adds phone sign-in to the same account, keeping its messages and theme. Signing in with a new number first would create a separate account.
- **Resending codes:** A 60-second cooldown prevents repeatedly tapping the resend button. Wrong codes and connection problems are shown on the screen.
- **Voice and video buttons:** The phone and camera buttons are connected in both themes. Stream handles the audio/video connection; Firebase remains responsible for accounts and text messages.
- **Incoming calls:** The app integration uses Stream's CallKit support. Apple shows the system incoming-call screen. Background incoming calls need Apple push credentials configured with Stream and should be tested on real devices.
- **Calling credentials:** The app asks a small server function for a temporary calling token. The server gets the user identity from Firebase, not from an ID supplied by the app. Stream's secret key stays on the server.
- **Inbox updates:** Conversations now save a participant list and last-message summary so they can appear in the other person's inbox and return after restarting the app. Existing message documents are preserved.
- **Local mode:** The “Talkr Local” scheme uses a dedicated LocalDebug build and a separate app identity (`com.insple.talkr.ios.local`). It points to a demo Firebase project running on your Mac, including when reopened from the simulator Home screen. It does not use the live Firebase project. Release builds cannot enable this mode.

## What “local” means

Code and configuration changes are on this Mac only. In the local scheme, authentication and text messages use Firebase emulators on this Mac. Stream voice/video still uses Stream's internet service after credentials are supplied; it is not an offline calling server.

The normal Talkr scheme continues to use the Firebase project already configured in the app. Use **Talkr Local** for isolated tests.

## Start the local services

From the project folder:

```sh
cd backend
npm ci
npm ci --prefix functions
npm start
```

The emulator dashboard is at http://127.0.0.1:4000. If it is already reachable, the services are running and you do not need to start a second copy. Keep the terminal running when you start them yourself. Test data is temporary and is cleared when the emulators are restarted unless you explicitly configure an export/import.

If npm reports a permission error for its cache, add `--cache /tmp/talkr-npm-cache` to the install commands.

## Test with two instances

1. In Xcode, select the **Talkr Local** scheme and an iPhone simulator. Run it.
2. Open a second, different iPhone simulator. Run the same scheme on that simulator too. Xcode may stop the first app when switching destinations. If so, reopen **Talkr Local** from the first simulator’s Home screen; it stays connected to the local services without needing Xcode attached.
3. Tap **Test account 1** on the first simulator and **Test account 2** on the second. This fills the fake numbers and display names without typing.
4. Tap **Send verification code**, then **Fill test code**, then **Verify and continue**. The local helper retrieves only the code for that exact pending verification request. Firebase still validates it; no real SMS is sent. Manual codes remain available at http://127.0.0.1:9099/emulator/v1/projects/demo-talkr/verificationCodes .
5. Tap `+` in the inbox and choose the other account. Send a message in each direction.
6. Check both themes, read receipts, and whether the conversation returns after restarting the app.
7. Sign out on one simulator and check that the previous account's conversations disappear.

These instructions are for simulators on the same Mac. A physical phone cannot reach your Mac through `127.0.0.1` without a separate development-network configuration.

## Enable real calls for local development

Text-message tests do not require a Stream account. Calls do.

1. Create/select a development Stream Video application.
2. Put its API key and secret in `backend/functions/.secret.local`, using `.secret.local.example` as the format. That file is ignored by Git. Never put the secret in Swift code or a plist.
3. Configure the Stream default call type for private, member-only calls. Both simulator accounts must sign in so the server registers them with Stream.
4. Restart the local services and sign in on both instances, or use the calling retry action.
5. Try the phone button for an audio call, then the camera button for video. Test accept, reject, hang up, mute, camera off/on, and denied permissions.

Simulator camera/audio behavior is limited. Use two physical devices for final microphone, camera, lock-screen, and background-call testing. Background calls additionally require an Apple developer account, push capability/provisioning, and a matching VoIP push provider configured with Stream.

## Before using live services later

Nothing in this list has been deployed or enabled by this work:

- Enable Firebase Phone Authentication, billing/quotas as required, and allowed SMS regions.
- Configure Firebase's Apple push credentials and confirm the reCAPTCHA URL scheme for the app.
- Configure Firebase App Check before deploying the calling-token function; the production function requires it.
- Deploy and review the backend and Firestore rules for your real environment. The rules in this project are used locally for now.
- Review existing conversation data before migration: older rooms have messages but may lack the new inbox summary. Opening a contact and sending a message creates that summary without deleting old messages.
- Configure Stream's private call permissions and Apple push provider.
- Add and verify production message push notifications and private phone-based contact discovery. The current contacts screen still lists registered Talkr users; phone numbers are not published in that directory.

## Files to know

| File | Purpose |
| --- | --- |
| `Talkr/PhoneAuthentication.swift` | Phone entry, code verification, and linking an existing account |
| `Talkr/CallingService.swift` | Connects signed-in users to Stream and starts calls |
| `Talkr/CallingUser.swift` | Keeps Stream's user type separate from Talkr's profile type |
| `Talkr/LocalDevelopment.swift` | Connects the local scheme to the emulators |
| `Talkr/Models.swift` | Accounts, conversation data, and live inbox updates |
| `Talkr/ContentView.swift` | Starts/stops account-specific services and displays call screens |
| `Talkr/TalkrApp.swift` | Configures Firebase before use and forwards phone-login notifications and callback URLs |
| `Talkr/OnboardingView.swift` | Opens the phone login screen while preserving email sign-in |
| `Talkr/ChatView.swift` | Connects call buttons and clears unread status when messages are read |
| `Talkr/InboxView.swift` | Adds the existing-account phone-link action to the profile context menu |
| `Configuration/` | Camera/microphone descriptions, push entitlement, and login callback settings |
| `backend/functions/index.js` | Creates temporary calling tokens for authenticated users |
| `backend/firestore.rules` | Restricts local conversations to their participants |
| `Talkr.xcodeproj/xcshareddata/xcschemes/Talkr Local.xcscheme` | The isolated simulator-testing scheme |

## Validation status

- **App build: passed.** The full Xcode build log ends with `BUILD SUCCEEDED`.
- **Local backend tests: passed (3 tests).** These check real emulator phone-code verification, rejection of a wrong code, messages in both directions, recipient-only read receipts, blocked access by a third account, rejected sender impersonation, and rejection of unauthenticated calling-token requests. Scheduled-message tests additionally check privacy, future times, cancellation, sender ownership, and duplicate-delivery protection.
- **Simulator phone sign-in: passed.** On an iPhone 17 simulator running iOS 27, a test account entered its name/number, requested an emulator code, verified it, and reached the Gen Z inbox. No overlapping text was seen. Contacts navigation and switching between Gen Z and Nostalgic also passed without overlapping or cropped elements.
- **Two-account UI messaging: partially verified.** UI Tester sent to Bob from Nostalgic mode; Bob saw the inbox entry and incoming bubble in Gen Z and sent a reply. The first account receiving that reply, read-receipt display, and simultaneous delivery are left for hands-on testing. Xcode stopped the other debug process when switching destinations. The dedicated local build now supports reopening from Home without losing emulator mode.
- **Live SMS: not tested.** Local testing uses printed emulator codes and sends no SMS.
- **Voice/video media: not tested.** Stream credentials have not been supplied. The call button was checked: it shows an unavailable/retry alert that dismisses without a crash.
- **Background incoming calls: not tested.** Apple/Stream push setup and physical-device testing are still needed.

Run the backend checks again with the emulators running:

```sh
cd backend
npm test
```

The tests create temporary emulator accounts and messages, then remove them. They do not access the live Firebase project.

## Current limitations

- New call screens currently use Stream's standard calling interface. The existing Talkr screens and both themes remain in place; the call buttons inherit the current theme.
- The Call Log tab remains a placeholder. A persistent missed-call history is not implemented in this local pass.
- Phone-number contact matching and message push notifications are not implemented in this pass. In-app messaging uses the existing registered-user directory.
- Local emulator services are bound to this Mac. Incoming messages update while the app is running; background message delivery notifications require additional work.
- The local tools use the installed Node 24 runtime; the function deployment target is Node 22. The local tests pass on Node 24, but deployment should be checked on Node 22.

## Design decisions

- Phone numbers identify accounts; they are not used as conversation IDs. Keeping the stable Firebase ID protects existing conversations when a number is linked.
- Phone numbers are not placed in the public user directory or used as fallback display names.
- A calling setup failure does not block sign-in or text messaging. Tapping a call button shows an error and offers retry.
- Calls are created with unique IDs. The recipient's camera starts off until they explicitly enable it.
- The local backend requires a Firebase login before issuing a calling token. A live deployment additionally requires App Check, which has not been configured here.
- Installed calling packages are pinned in the project/lockfiles so another local build resolves the same versions.


## Reference documentation

- [Firebase phone authentication for Apple apps](https://firebase.google.com/docs/auth/ios/phone-auth)
- [Firebase Authentication emulator](https://firebase.google.com/docs/emulator-suite/connect_auth)
- [Stream iOS calling SDK](https://getstream.io/video/docs/ios/)
- [Stream CallKit integration](https://getstream.io/video/docs/ios/advanced/incoming-calls/callkit-integration/)

## Issues found and fixed during testing

- Firebase checks dummy IDs and keys even in emulator mode. The local placeholders now have valid formats, without using real credentials.
- Firebase checks the login callback URL even in emulator mode. The normal app registers its live callback; Talkr Local registers a separate demo callback.
- Firebase needed its notification callbacks connected and initialization moved to the app-delegate launch step. Moving it too early prevented verification codes from being requested.
- Stream's call handling cannot be initialized before its client exists. Startup and logout now leave it alone until calling is configured, so text-only testing works without Stream credentials.
- New phone profiles needed a saved default theme to decode correctly in the existing contacts list. That default is now saved.
- The resend-code cooldown is visible even after changing the phone number.

- New conversations now save their participant list before loading messages, so access rules do not reject the first message listener.
- Inbox updates now use the live database result instead of a saved array position, avoiding a race when conversations reorder.

- A dedicated local build now keeps emulator mode enabled after reopening the app from Home. Its separate app identity also prevents sharing saved sign-in state with the normal build.
- The phone-field placeholder was shortened after it was truncated on the smaller simulator.

## Hands-on handoff

Xcode is set to **Talkr Local**. Emulator services are running. Use fake numbers `+15555550101` and `+15555550102` on separate simulators. No password is needed. Each code is generated only after tapping **Send verification code**; tap **Fill test code** to enter it automatically, then **Verify and continue**. Previously used codes are consumed and should not be reused. All automated device-interaction sessions have ended so you can control the simulators.

## Troubleshooting simulator login and typing

- Open **Talkr Local**, not **Talkr**. The local login screen explicitly says “Local testing · No SMS is sent” and has test-account buttons. Normal Talkr uses live Firebase and cannot verify these fake numbers.
- Normal and local builds now register separate authentication callback URLs, preventing a login callback from opening the other app.
- Use **Test account 1/2** and **Fill test code** to avoid typing altogether. These helpers only run in debug emulator mode and do not bypass code verification.
- To paste manually on Mac, use Command–V (not Shift) or Simulator’s Edit → Paste menu. Make sure the intended field is focused.

### Verification after the simulator login fix

The latest Talkr Local build was installed on both simulators. On the first, Test account 1 → Send verification code → Fill test code → Verify successfully signed Alice Test in and opened the inbox. The app stayed in the local build throughout. The second simulator is left at the local login screen, ready for Test account 2. Device-control sessions have ended. If Xcode stopped the first app while installing the second, reopen Talkr Local from its Home screen. No GitHub changes were made.
