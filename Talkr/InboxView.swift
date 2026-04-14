import SwiftUI

struct InboxView: View {
    @Binding var isLoggedIn: Bool
    @EnvironmentObject var store: ChatStore
    @State private var unreadFilter = false
    @State private var selectedTab = "Messages"
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                TopThemeBar()
                
                HStack(spacing: 20) {
                    Button(action: { selectedTab = "Messages" }) {
                        Text("Messages")
                            .font(.title2)
                            .fontWeight(selectedTab == "Messages" ? .bold : .medium)
                            .foregroundColor(.black)
                    }
                    Button(action: { selectedTab = "Groups" }) {
                        Text("Groups")
                            .font(.title2)
                            .fontWeight(selectedTab == "Groups" ? .bold : .medium)
                            .foregroundColor(.black)
                    }
                    Button(action: { selectedTab = "Call Log" }) {
                        Text("Call Log")
                            .font(.title2)
                            .fontWeight(selectedTab == "Call Log" ? .bold : .medium)
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal)
                
                if selectedTab == "Messages" {
                    HStack {
                        Button(action: { unreadFilter = false }) {
                            Text("All")
                                .font(.subheadline)
                                .foregroundColor(!unreadFilter ? .white : .black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(!unreadFilter ? Color.black : Color.clear)
                                .clipShape(Capsule())
                        }
                        
                        Button(action: { unreadFilter = true }) {
                            Text("Unread")
                                .font(.subheadline)
                                .foregroundColor(unreadFilter ? .white : .black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(unreadFilter ? Color.black : Color.clear)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        NavigationLink(destination: ContactsView()) {
                            Image(systemName: "plus")
                                .font(.footnote)
                                .foregroundColor(.black)
                                .padding(10)
                                .overlay(
                                    Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.chats.filter { chat in !unreadFilter || chat.isUnread }) { chat in
                                NavigationLink(destination: ChatView(chat: chat)) {
                                    ChatRow(chat: chat)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                } else if selectedTab == "Groups" {
                    Spacer()
                    Text("Groups coming soon...")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else if selectedTab == "Call Log" {
                    Spacer()
                    Text("Call logs coming soon...")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
            }
            
            // Floating Action Button
            Button(action: { isLoggedIn = false }) {
                Text("Me")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.black)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 5)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
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
                    Text(chat.partner.name.components(separatedBy: ",").first ?? chat.partner.name)
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
