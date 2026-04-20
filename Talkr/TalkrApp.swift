import SwiftUI

@main
struct TalkrApp: App {
    // Keep existing AppDelegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Inject global services
    @StateObject private var auth  = AuthService.shared
    @StateObject private var theme = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(theme)
        }
    }
}
