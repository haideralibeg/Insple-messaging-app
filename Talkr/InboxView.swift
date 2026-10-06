import SwiftUI

struct InboxView: View {
    @EnvironmentObject var store: ChatStore
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var theme: ThemeManager
    @State private var unreadFilter = false
    @State private var selectedTab  = "Messages"

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
                        filterPill("All",    active: !unreadFilter) { unreadFilter = false }
                        filterPill("Unread", active:  unreadFilter) { unreadFilter = true  }
                        Spacer()
                        NavigationLink(destination: ContactsView()) {
                            Image(systemName: "plus")
                                .font(.footnote)
                                .foregroundColor(theme.secondaryTextColor)
                                .padding(10)
                                .overlay(Circle().stroke(theme.secondaryTextColor.opacity(0.3), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal)

                    if store.chats.filter({ !unreadFilter || $0.isUnread }).isEmpty {
                        Text(unreadFilter ? "No unread messages." : (theme.isNostalgic ? "Your buddy list is waiting. Tap + to start a chat." : "Tap + to start a conversation."))
                            .font(.system(.subheadline, design: theme.isNostalgic ? .monospaced : .default))
                            .foregroundColor(theme.secondaryTextColor)
                            .padding()
                    }
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.chats.filter { !unreadFilter || $0.isUnread }) { chat in
                                NavigationLink(destination: ChatView(chat: chat)) {
                                    ChatRow(chat: chat)
                                }
                                .buttonStyle(PlainButtonStyle())
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

            // FAB
            Button(action: { auth.logout() }) {
                Text(auth.currentUser?.displayName.prefix(1).uppercased() ?? "Me")
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(theme.primaryTextColor)
                    .frame(width: 56, height: 56)
                    .background(theme.primaryColor)
                    .clipShape(Circle())
                    .shadow(color: theme.primaryColor.opacity(0.4), radius: 5, x: 0, y: 5)
            }
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
    private func filterPill(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
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
            Circle()
                .fill(chat.isUnread ? theme.unreadDotColor : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.leading, 8)

            AvatarView(size: 50, showUnreadDot: false)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom, spacing: 6) {
                    Text(chat.partner.name.components(separatedBy: ",").first ?? chat.partner.name)
                        .font(.headline)
                        .fontWeight(chat.isUnread ? .bold : .semibold)
                        .foregroundColor(theme.secondaryTextColor)
                    Text(chat.timeAgo)
                        .font(.subheadline)
                        .foregroundColor(theme.secondaryTextColor.opacity(0.4))
                }
                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryTextColor.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .background(theme.backgroundColor)
        .overlay(Divider().background(theme.subtleColor), alignment: .bottom)
    }
}
