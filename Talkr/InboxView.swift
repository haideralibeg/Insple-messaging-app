import SwiftUI

struct InboxView: View {
    @EnvironmentObject var store: ChatStore
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var theme: ThemeManager
    @State private var unreadFilter = false
    @State private var selectedTab  = "Messages"

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                TopThemeBar()

                HStack(spacing: 20) {
                    tabButton("Messages")
                    tabButton("Groups")
                    tabButton("Call Log")
                }
                .padding(.horizontal)

                if selectedTab == "Messages" {
                    HStack {
                        filterButton("All",    active: !unreadFilter) { unreadFilter = false }
                        filterButton("Unread", active:  unreadFilter) { unreadFilter = true  }

                        Spacer()

                        NavigationLink(destination: ContactsView()) {
                            Image(systemName: "plus")
                                .font(.footnote)
                                .foregroundColor(.black)
                                .padding(10)
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal)

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

            // FAB — shows user initial, tapping logs out
            Button(action: { auth.logout() }) {
                Text(auth.currentUser?.displayName.prefix(1).uppercased() ?? "Me")
                    .font(.headline).fontWeight(.bold).foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.black)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
            }
            .padding()
        }
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func tabButton(_ title: String) -> some View {
        Button(action: { selectedTab = title }) {
            Text(title)
                .font(.title2)
                .fontWeight(selectedTab == title ? .bold : .medium)
                .foregroundColor(.black)
        }
    }

    @ViewBuilder
    private func filterButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(active ? .white : .black)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(active ? Color.black : Color.clear)
                .clipShape(Capsule())
        }
    }
}

struct ChatRow: View {
    var chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(size: 50, showUnreadDot: chat.isUnread)
                .padding(.leading, chat.isUnread ? 16 : 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom, spacing: 6) {
                    Text(chat.partner.name.components(separatedBy: ",").first
                         ?? chat.partner.name)
                        .font(.headline)
                        .fontWeight(chat.isUnread ? .bold : .semibold)
                        .foregroundColor(.black)
                    Text(chat.timeAgo)
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray3))
                }
                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .background(Color.white)
    }
}
