import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false
    @StateObject private var store = ChatStore()
    
    var body: some View {
        Group {
            if isLoggedIn {
                NavigationStack {
                    InboxView(isLoggedIn: $isLoggedIn)
                }
                .environmentObject(store)
            } else {
                OnboardingView(isLoggedIn: $isLoggedIn)
            }
        }
        .animation(.easeInOut, value: isLoggedIn)
    }
}

