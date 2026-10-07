import SwiftUI

enum Route: Hashable {
    case contacts
    case chat(Chat)
}

struct ContentView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: ChatStore
    @State private var path: [Route] = []

    var body: some View {
        Group {
            if auth.isAuthenticated {
                NavigationStack(path: $path) {
                    InboxView(path: $path)
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .contacts:
                                ContactsView(path: $path)
                            case .chat(let chat):
                                ChatView(chat: chat)
                            }
                        }
                }
                .onAppear { store.fetchContacts() }
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated)
    }
}
