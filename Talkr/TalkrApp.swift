import SwiftUI
import FirebaseCore 

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct TalkrApp: App { // (If your file is named differently, keep your original struct name here)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // 1. We create the managers right when the app turns on
    @StateObject private var chatStore = ChatStore()
    @StateObject private var authService = AuthService()
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 2. We shove them into the App's "Backpack" so every screen can find them!
                .environmentObject(chatStore)
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
    }
}
