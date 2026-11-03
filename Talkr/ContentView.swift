import SwiftUI

enum Route: Hashable {
    case contacts
    case chat(Chat)
}

struct ContentView: View {
    @State private var path: [Route] = []
    @EnvironmentObject var auth: AuthService
    @State private var calling = CallingService()
    @State private var scheduled = ScheduledMessageStore()
    @EnvironmentObject private var store: ChatStore
    
    var body: some View {
        Group {
            if auth.isAuthenticated {
                NavigationStack(path: $path) {
                    InboxView(path: $path)
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .contacts: ContactsView(path: $path)
                            case .chat(let chat): ChatView(chat: chat)
                            }
                        }
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
            guard !auth.isPreview else { return }
            path = []
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
