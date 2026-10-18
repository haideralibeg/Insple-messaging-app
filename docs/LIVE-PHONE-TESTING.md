# Real SMS verification setup

> Checkpoint: the owner subsequently authorized committing and pushing this work to a new feature branch. Earlier no-push statements below describe the implementation period. Main remains untouched. See PROGRESS.md for the saved status.
## Current status

The app already contains Firebase phone verification, SMS-code entry, and the callback URL for the live iOS app. The normal **Talkr** scheme uses Firebase project `insple-talkr`, bundle ID `com.insple.talkr.ios`. **Talkr Local** remains connected to the emulators and never sends SMS.

Firebase CLI reauthentication is complete. Live API checks confirmed phone sign-in is already enabled, the expected Firebase web domains are authorized, and billing is disabled. With the owner's request to enable real SMS and confirmation that the test number is US, the previously empty SMS region policy was changed to allow only US numbers. A follow-up API read confirmed that policy. No SMS has been sent yet.

The remaining blocker is billing: the owner needs to attach a billing account / enable the Blaze plan for `insple-talkr`. No billing account was selected or attached by this work. No push or merge was performed.

## Paused by owner

Billing setup is on hold at the owner’s request. Do not attach billing or continue real-SMS testing until asked. The US-only policy remains configured; no real SMS was sent.

## Next steps when resumed

1. Open Firebase project `insple-talkr` and enable the Blaze plan by attaching the owner's chosen billing account.
2. Tell the assistant when billing is enabled so it can verify the status.
3. Build/run **Talkr** (not Talkr Local), enter the real US number with `+1`, complete any reCAPTCHA, request a code, then enter the SMS code directly in the app.
4. Verify sign-in and profile loading. This uses live accounts and the live database; local emulator conversations do not transfer. Existing account holders should sign in with email and link their number to retain that account's conversations.

Simulator phone verification uses reCAPTCHA. Physical-device silent verification additionally needs an APNs authentication key uploaded to Firebase. The callback URL and notification forwarding are already in the app; uploaded Apple credentials have not been checked.

Voice/video credentials and hosted scheduled-message delivery are separate work. Enabling SMS login does not enable those services. Scheduling currently remains available only in Talkr Local.

## References

- [Firebase Apple phone authentication setup](https://firebase.google.com/docs/auth/ios/phone-auth)
- [Firebase SMS limits and Blaze requirement](https://firebase.google.com/docs/auth/limits)

## Xcode scheme preparation

Xcode currently exposes only Talkr Local. Added an explicit shared Talkr scheme using the existing Debug configuration (live bundle and Firebase plist). Its XML was validated. Xcode has not yet picked up that new scheme; reopen the project to refresh its scheme list. The current local scheme built successfully; the new live scheme still needs a build and hands-on SMS verification after refresh and billing setup.
