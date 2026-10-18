import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        LocalDevelopment.configureFirebase()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Auth.auth().canHandle(url)
    }
}

@main
struct TalkrApp: App { // (If your file is named differently, keep your original struct name here)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    
    // 1. We create the managers right when the app turns on
    @StateObject private var chatStore = ChatStore()
    @StateObject private var authService = AuthService.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in _ = Auth.auth().canHandle(url) }
                // 2. We shove them into the App's "Backpack" so every screen can find them!
                .environmentObject(chatStore)
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
    }
}
