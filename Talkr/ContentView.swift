import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthService
    
    var body: some View {
        Group {
            if auth.isAuthenticated {
                if auth.isEmailVerified {
                    NavigationStack {
                        InboxView()
                    }
                } else {
                    VerifyEmailView()
                }
            } else {
                // The $ creates a perfect 2-way connection to the Auth manager!
                OnboardingView()
            }
        }
        // This makes the screen slide nicely when the value changes
        .animation(.easeInOut, value: auth.isAuthenticated)
        .animation(.easeInOut, value: auth.isEmailVerified)
    }
}
