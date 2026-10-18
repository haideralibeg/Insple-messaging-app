import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthService
    @State private var calling = CallingService()
    @State private var scheduled = ScheduledMessageStore()
    @EnvironmentObject private var store: ChatStore
    
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
        .environment(calling)
        .environment(scheduled)
        .overlay {
            if let viewModel = calling.viewModel {
                TalkrCallOverlay(viewModel: viewModel)
            }
        }
        .task(id: auth.currentUser?.id) {
            store.observeInbox(userID: auth.currentUser?.id)
            scheduled.observe(userID: auth.currentUser?.id)
            await calling.connect(userID: auth.currentUser?.id, name: auth.currentUser?.name ?? "Talkr user")
        }
        .alert("Calling unavailable", isPresented: Binding(
            get: { calling.errorMessage != nil },
            set: { if !$0 { calling.errorMessage = nil } }
        )) {
            Button("Retry") {
                Task { await calling.connect(userID: auth.currentUser?.id, name: auth.currentUser?.name ?? "Talkr user") }
            }
            Button("OK", role: .cancel) { calling.errorMessage = nil }
        } message: {
            Text(calling.errorMessage ?? "")
        }
        // This makes the screen slide nicely when the value changes
        .animation(.easeInOut, value: auth.isAuthenticated)
    }
}
