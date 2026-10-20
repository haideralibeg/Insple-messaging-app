#if DEBUG
import SwiftUI

enum Route: Hashable {
    case contacts
    case chat(Chat)
}

/// Each canvas owns its state so previews can be edited and interacted with independently.
struct PreviewHost<Content: View>: View {
    @StateObject private var auth: AuthService
    @StateObject private var store: ChatStore
    @StateObject private var theme: ThemeManager
    @State private var path: [Route] = []
    private let content: (Binding<[Route]>) -> Content

    init(mode: String = "genz", authenticated: Bool = true, empty: Bool = false,
         @ViewBuilder content: @escaping (Binding<[Route]>) -> Content) {
        let auth = AuthService(isPreview: true)
        auth.currentUser = User(id: "preview-me", name: "Sam Taylor", activeMode: mode)
        auth.isAuthenticated = authenticated
        let store = ChatStore(isPreview: true)
        store.contacts = PreviewData.contacts
        store.chats = empty ? [] : PreviewData.chats
        let theme = ThemeManager(isPreview: true)
        theme.activeMode = mode
        _auth = StateObject(wrappedValue: auth)
        _store = StateObject(wrappedValue: store)
        _theme = StateObject(wrappedValue: theme)
        self.content = content
    }

    var body: some View {
        NavigationStack(path: $path) {
            content($path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .contacts: ContactsView()
                    case .chat(let chat): ChatView(chat: chat)
                    }
                }
        }
        .environmentObject(auth)
        .environmentObject(store)
        .environmentObject(theme)
        .preferredColorScheme(theme.isNostalgic || !auth.isAuthenticated ? .light : .dark)
    }
}

enum PreviewData {
    static let contacts = [
        User(id: "preview-alex", name: "Alex Morgan"),
        User(id: "preview-jamie", name: "Jamie Chen"),
        User(id: "preview-riley", name: "Riley Jordan")
    ]
    static let messages = [
        ChatMessage(id: "preview-1", senderId: "preview-alex", content: "Hey! Are we still meeting for coffee?", timestamp: Date(timeIntervalSince1970: 1_792_512_000), isIncoming: true),
        ChatMessage(id: "preview-2", senderId: "preview-me", content: "Absolutely! See you at 3.", timestamp: Date(timeIntervalSince1970: 1_792_512_060), isIncoming: false, isRead: true),
        ChatMessage(id: "preview-3", senderId: "preview-alex", content: "Perfect, see you there!", timestamp: Date(timeIntervalSince1970: 1_792_512_120), isIncoming: true)
    ]
    static let chats = [
        Chat(id: "preview-chat-alex", partner: contacts[0], lastMessage: "Perfect, see you there!", timeAgo: "2m", isUnread: true, messages: messages),
        Chat(id: "preview-chat-jamie", partner: contacts[1], lastMessage: "Thanks for sending the photos!", timeAgo: "1h", isUnread: false, messages: []),
        Chat(id: "preview-chat-riley", partner: contacts[2], lastMessage: "Let's catch up this weekend.", timeAgo: "Yesterday", isUnread: false, messages: [])
    ]
}
#endif

