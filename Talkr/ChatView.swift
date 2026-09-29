import SwiftUI

struct ChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: ChatStore
    @EnvironmentObject var theme: ThemeManager
    var chat: Chat
    @State private var messageText = ""

    var liveChat: Chat {
        store.chats.first(where: { $0.id == chat.id }) ?? chat
    }

    var body: some View {
        VStack(spacing: 0) {
            if theme.isNostalgic {
                HStack {
                    Button { presentationMode.wrappedValue.dismiss() } label: {
                        Label("Buddy list", systemImage: "chevron.left")
                    }
                    .buttonStyle(RetroButtonStyle())
                    Spacer()
                }
                .padding(.horizontal, 10).padding(.top, 8)
            }
            TopThemeBar()
            if theme.isNostalgic {
                NostalgicConversation(chat: liveChat, messageText: $messageText, send: sendMessage)
            } else {
                // Header
                HStack(spacing: 16) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(theme.secondaryTextColor)
                    }

                    AvatarView(size: 40, showUnreadDot: false)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(chat.partner.name.components(separatedBy: ",").first ?? chat.partner.name)
                            .font(.headline).fontWeight(.bold)
                            .foregroundColor(theme.secondaryTextColor)
                        Text("Direct message")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                    }

                    Spacer()

                    HStack(spacing: 20) {
                        Button(action: {}) {
                            Image(systemName: "phone")
                                .font(.title3)
                                .foregroundColor(theme.secondaryTextColor)
                        }
                        Button(action: {}) {
                            Image(systemName: "video")
                                .font(.title3)
                                .foregroundColor(theme.secondaryTextColor)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(theme.backgroundColor)

                // Messages
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(spacing: 8) {
                            Text((liveChat.messages.first?.timestamp ?? Date()).formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(theme.secondaryTextColor.opacity(0.4))
                                .padding(.top, 20).padding(.bottom, 10)

                            ForEach(liveChat.messages) { message in
                                VStack(alignment: message.isIncoming ? .leading : .trailing, spacing: 2) {
                                    HStack(alignment: .bottom, spacing: 8) {
                                        if message.isIncoming {
                                            Circle()
                                                .fill(theme.primaryColor)
                                                .frame(width: 24, height: 24)
                                        } else {
                                            Spacer()
                                        }

                                        Text(message.content)
                                            .foregroundColor(message.isIncoming
                                                ? theme.secondaryTextColor
                                                : theme.primaryTextColor)
                                            .padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(message.isIncoming
                                                ? theme.incomingBubbleColor
                                                : theme.outgoingBubbleColor)
                                            .cornerRadius(20)

                                        if message.isIncoming {
                                            Spacer()
                                        }
                                    }

                                    if !message.isIncoming, message.id == liveChat.messages.last(where: { !$0.isIncoming })?.id {
                                        ReadReceiptView(isRead: message.isRead)
                                            .padding(.trailing, 8)
                                    }
                                }
                                .padding(.horizontal)
                                .id(message.id)
                            }
                        }
                        .onChange(of: liveChat.messages.count) { _ in
                            if let last = liveChat.messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                            store.markMessagesAsRead(in: liveChat)
                        }
                    }
                }
                .background(theme.backgroundColor)

                // Input bar
                HStack(spacing: 12) {
                    HStack {
                        TextField("Message...", text: $messageText)
                            .foregroundColor(theme.secondaryTextColor)
                            .onSubmit { sendMessage() }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(theme.subtleColor)
                    .cornerRadius(20)

                    if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .font(.title2)
                                .foregroundColor(theme.outgoingBubbleColor)
                        }
                    } else {
                        Button(action: {}) {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal).padding(.vertical, 10)
                .background(theme.backgroundColor)
            }
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .navigationBarHidden(true)
        .animation(.easeInOut(duration: 0.3), value: theme.activeMode)
        .onAppear {
            store.markAsRead(chat)
            store.startListening(to: chat)
            store.markMessagesAsRead(in: chat)
        }
        .onChange(of: liveChat.messages) { _ in
            store.markMessagesAsRead(in: liveChat)
        }
        .onDisappear { store.stopListening() }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.sendMessage(messageText, in: chat)
        if theme.isNostalgic { NostalgicSounds.shared.play(.sent) }
        messageText = ""
    }
}
