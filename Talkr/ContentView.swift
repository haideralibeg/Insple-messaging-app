import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthService
    
    var body: some View {
        Group {
            if auth.isAuthenticated {
                NavigationStack {
                    InboxView()
                }
            } else {
                // The $ creates a perfect 2-way connection to the Auth manager!
                OnboardingView()
            }
        }
        // This makes the screen slide nicely when the value changes
        .animation(.easeInOut, value: auth.isAuthenticated)
    }
}

#if DEBUG
#Preview("App — Gen Z") {
    PreviewHost { _ in ContentView() }
}

#Preview("App — Nostalgic") {
    PreviewHost(mode: "nostalgic") { _ in ContentView() }
}

#Preview("App — Signed Out") {
    PreviewHost(authenticated: false) { _ in ContentView() }
}

#endif
