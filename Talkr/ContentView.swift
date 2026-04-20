import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var theme: ThemeManager
    @StateObject private var store = ChatStore()

    var body: some View {
        Group {
            if auth.isAuthenticated {
                NavigationStack {
                    InboxView()
                }
                .environmentObject(store)
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated)
    }
}

