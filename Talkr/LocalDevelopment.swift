import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

enum LocalDevelopment {
    static var usesEmulators: Bool {
        #if DEBUG
        Bundle.main.object(forInfoDictionaryKey: "TalkrUseEmulators") as? Bool == true
        #else
        false
        #endif
    }

    static func configureFirebase() {
        guard FirebaseApp.app() == nil else { return }
        if usesEmulators {
            // A demo project cannot accidentally reach production Firebase resources.
            let options = FirebaseOptions(
                googleAppID: "1:1234567890:ios:1111222233334444",
                gcmSenderID: "1234567890"
            )
            options.apiKey = "AIza00000000000000000000000000000000000"
            options.projectID = "demo-talkr"
            FirebaseApp.configure(options: options)
            Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
            Auth.auth().settings?.isAppVerificationDisabledForTesting = true
            let database = Firestore.firestore()
            let settings = database.settings
            settings.host = "127.0.0.1:8080"
            settings.isSSLEnabled = false
            database.settings = settings
            Functions.functions().useEmulator(withHost: "127.0.0.1", port: 5001)
        } else {
            FirebaseApp.configure()
        }
    }
}
