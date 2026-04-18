import SwiftUI

struct ChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: ChatStore
    var chat: Chat
    @State private var messageText = ""
    
    // live up-to-date version of this conversation.
    var liveChat: Chat {
        store.chats.first(where: { $0.id == chat.id }) ?? chat
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                
                AvatarView(size: 40, showUnreadDot: false)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chat.partner.name.components(separatedBy: ",").first ?? chat.partner.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Active 10m ago")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: {}) {
                        Image(systemName: "phone")
                            .font(.title3)
                            .foregroundColor(.black)
                    }
                    Button(action: {}) {
                        Image(systemName: "video")
                            .font(.title3)
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .background(Color.white)
            
            // Chat Array
            ScrollView {
                VStack(spacing: 8) {
                    Text("Jan 01, 2028, 9:41 AM")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    // use "liveChat" here instead of "chat" so it updates automatically
                    ForEach(liveChat.messages) { message in
                        HStack(alignment: .bottom, spacing: 8) {
                            if message.isIncoming {
                                // Mock avatar clustering - always show for now
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 24, height: 24)
                            } else {
                                Spacer()
                            }
                            
                            Text(message.content)
                                .foregroundColor(message.isIncoming ? .black : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(message.isIncoming ? Color(.systemGray5) : Color.black)
                                .cornerRadius(20)
                            
                            if message.isIncoming {
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .background(Color.white)
            
            // Bottom Input
            HStack(spacing: 12) {
                HStack {
                    // .onSubmit lets you press "Return" on your keyboard to send
                    TextField("Message...", text: $messageText)
                        .onSubmit {
                            sendMessage()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                
                // If we typed something, show a Send button.
                // If it is empty, show the Photo button!
                if !messageText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .foregroundColor(.black)
                    }
                } else {
                    Button(action: {}) {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.white)
        }
        .navigationBarHidden(true)
        .onAppear {
            store.markAsRead(chat)
        }
    }
    
    // what to do when we send a message
    private func sendMessage() {
        // 1. Make sure the message isn't just invisible spaces
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // 2. Hand the message to our Store (the big brain that remembers everything)
        store.sendMessage(messageText, in: chat)
        
        // 3. Erase the text box so it's clean for the next message
        messageText = ""
    }
}
