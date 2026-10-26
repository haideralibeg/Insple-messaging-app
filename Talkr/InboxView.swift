import SwiftUI

struct InboxView: View {
    @EnvironmentObject var store: ChatStore
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var theme: ThemeManager
    @Binding var path: [Route]
    @State private var unreadFilter = false
    @State private var selectedTab  = "Messages"

    private var visibleChats: [Chat] {
        var seen = Set<String>()
        let deduped = store.chats.filter { seen.insert($0.id).inserted }
        return deduped.filter { !unreadFilter || $0.isUnread }
    }

    private var unreadCount: Int { store.chats.filter { $0.isUnread }.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            theme.backgroundColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                TopThemeBar()
                if theme.isNostalgic {
                    HStack {
                        Label("Buddy list", systemImage: "person.2.fill")
                        Spacer()
                        Text("\(store.chats.count) conversations")
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(RetroPalette.ink)
                    .padding(10)
                    .background(RetroPalette.panel)
                    .modifier(RetroPanel())
                    .padding(.horizontal, 10)
                }

                HStack(spacing: 20) {
                    tabButton("Messages")
                    tabButton("Groups")
                    tabButton("Call Log")
                }
                .padding(.horizontal)

                if selectedTab == "Messages" {
                    HStack {
                        filterPill("All", active: !unreadFilter) { unreadFilter = false }
                        filterPill("Unread", active: unreadFilter, badge: unreadCount) { unreadFilter = true }
                        Spacer()
                        Button(action: { path.append(.contacts) }) {
                            Image(systemName: "plus")
                                .font(.footnote)
                                .foregroundColor(theme.secondaryTextColor)
                                .padding(10)
                                .overlay(Circle().stroke(theme.secondaryTextColor.opacity(0.3), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal)

                    if visibleChats.isEmpty {
                        if unreadFilter {
                            VStack(spacing: 10) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(theme.secondaryTextColor.opacity(0.3))
                                Text("You're all caught up")
                                    .font(.subheadline)
                                    .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                        } else {
                            Text(theme.isNostalgic ? "Your buddy list is waiting. Tap + to start a chat." : "Tap + to start a conversation.")
                                .font(.system(.subheadline, design: theme.isNostalgic ? .monospaced : .default))
                                .foregroundColor(theme.secondaryTextColor)
                                .padding()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(visibleChats) { chat in
                                    Button(action: { path.append(.chat(chat)) }) {
                                        ChatRow(chat: chat)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                } else {
                    Spacer()
                    Text("\(selectedTab) coming soon...")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Profile entry point
            NavigationLink(destination: ProfileView()) {
                Text(auth.currentUser?.displayName.prefix(1).uppercased() ?? "Me")
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(theme.primaryTextColor)
                    .frame(width: 56, height: 56)
                    .background(theme.primaryColor)
                    .clipShape(Circle())
                    .shadow(color: theme.primaryColor.opacity(0.4), radius: 5, x: 0, y: 5)
            }
            .accessibilityLabel("Open your profile")
            .padding()
        }
        .preferredColorScheme(theme.isNostalgic ? .light : .dark)
        .navigationBarHidden(true)
        .animation(.easeInOut(duration: 0.3), value: theme.activeMode)
    }

    @ViewBuilder
    private func tabButton(_ title: String) -> some View {
        Button(action: { selectedTab = title }) {
            Text(title)
                .font(theme.isNostalgic ? .system(.headline, design: .monospaced) : theme.tabFont)
                .fontWeight(selectedTab == title ? .bold : .medium)
                .foregroundColor(selectedTab == title ? theme.secondaryTextColor : theme.secondaryTextColor.opacity(0.4))
        }
    }

    @ViewBuilder
    private func filterPill(_ title: String, active: Bool, badge: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.subheadline)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundColor(active ? theme.primaryColor : theme.primaryTextColor)
                        .padding(5)
                        .background(active ? theme.primaryTextColor : theme.unreadDotColor)
                        .clipShape(Circle())
                }
            }
            .foregroundColor(active ? theme.primaryTextColor : theme.secondaryTextColor)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(active ? theme.primaryColor : Color.clear)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(active ? Color.clear : theme.secondaryTextColor.opacity(0.2), lineWidth: 1))
        }
    }
}

struct ChatRow: View {
    @EnvironmentObject var theme: ThemeManager
    var chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(size: 50, showUnreadDot: false)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom, spacing: 6) {
                    Text(chat.partner.name.components(separatedBy: ",").first ?? chat.partner.name)
                        .font(.headline)
                        .fontWeight(chat.isUnread ? .bold : .semibold)
                        .foregroundColor(theme.secondaryTextColor)
                    Spacer()
                    Text(chat.timeAgo)
                        .font(.subheadline)
                        .foregroundColor(chat.isUnread ? theme.unreadDotColor : theme.secondaryTextColor.opacity(0.4))
                }
                HStack(spacing: 6) {
                    Text(chat.lastMessage)
                        .font(.subheadline)
                        .fontWeight(chat.isUnread ? .semibold : .regular)
                        .foregroundColor(chat.isUnread ? theme.secondaryTextColor.opacity(0.9) : theme.secondaryTextColor.opacity(0.6))
                        .lineLimit(1)
                    Spacer()
                    if chat.isUnread {
                        Circle()
                            .fill(theme.unreadDotColor)
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .padding(.horizontal).padding(.vertical, 12)
        .background(theme.backgroundColor)
        .overlay(Divider().background(theme.subtleColor), alignment: .bottom)
    }
}

#if DEBUG
#Preview("Inbox — Gen Z") {
    PreviewHost { _ in InboxView() }
}

#Preview("Inbox — Nostalgic") {
    PreviewHost(mode: "nostalgic") { _ in InboxView() }
}

#Preview("Inbox — Empty") {
    PreviewHost(empty: true) { _ in InboxView() }
}

#Preview("Chat Row") {
    PreviewHost { _ in ChatRow(chat: PreviewData.chats[0]) }
}

#endif
