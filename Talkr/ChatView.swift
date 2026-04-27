import SwiftUI

struct ChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: ChatStore
    @EnvironmentObject var theme: ThemeManager
    var chat: Chat
    @State private var messageText = ""
    @State private var isShowingScheduleOptions = false
    @State private var scheduledDate = Date().addingTimeInterval(900)

    var liveChat: Chat {
        store.chats.first(where: { $0.id == chat.id }) ?? chat
    }

    var pendingMessages: [ScheduledMessage] {
        store.pendingScheduledMessages(for: liveChat)
    }

    var body: some View {
        VStack(spacing: 0) {
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
                    Text("Active 10m ago")
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
                        Text("Jan 01, 2028, 9:41 AM")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor.opacity(0.4))
                            .padding(.top, 20).padding(.bottom, 10)

                        ForEach(liveChat.messages) { message in
                            VStack(alignment: message.isIncoming ? .leading : .trailing, spacing: 3) {
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

                                if !message.isIncoming {
                                    Text(readReceiptText(for: message))
                                        .font(.caption2)
                                        .foregroundColor(theme.secondaryTextColor.opacity(0.45))
                                        .padding(.trailing, 8)
                                }
                            }
                            .padding(.horizontal)
                            .id(message.id)
                        }

                        ForEach(pendingMessages) { message in
                            VStack(alignment: .trailing, spacing: 3) {
                                HStack(alignment: .bottom, spacing: 8) {
                                    Spacer()
                                    Text(message.content)
                                        .foregroundColor(theme.primaryTextColor.opacity(0.75))
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(theme.outgoingBubbleColor.opacity(0.55))
                                        .cornerRadius(20)
                                }

                                Label("Scheduled \(scheduledTimeText(for: message.scheduledFor))", systemImage: "clock")
                                    .font(.caption2)
                                    .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                                    .padding(.trailing, 8)
                            }
                            .padding(.horizontal)
                            .id(message.id)
                        }
                    }
                    .onChange(of: liveChat.messages.count + pendingMessages.count) {
                        if let lastPending = pendingMessages.last {
                            withAnimation { proxy.scrollTo(lastPending.id, anchor: .bottom) }
                        } else if let last = liveChat.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
            .background(theme.backgroundColor)

            // Input bar
            VStack(spacing: 8) {
                if isShowingScheduleOptions {
                    HStack(spacing: 12) {
                        DatePicker(
                            "Send",
                            selection: $scheduledDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .tint(theme.outgoingBubbleColor)

                        Button(action: scheduleMessage) {
                            Text("Schedule")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.primaryTextColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(theme.outgoingBubbleColor)
                                .clipShape(Capsule())
                        }
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.subtleColor)
                    .cornerRadius(16)
                }

                HStack(spacing: 12) {
                    Button(action: toggleScheduleOptions) {
                        Image(systemName: "clock")
                            .font(.title2)
                            .foregroundColor(isShowingScheduleOptions ? theme.outgoingBubbleColor : theme.secondaryTextColor.opacity(0.5))
                    }

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
            }
            .padding(.horizontal).padding(.vertical, 10)
            .background(theme.backgroundColor)
        }
        .navigationBarHidden(true)
        .animation(.easeInOut(duration: 0.3), value: theme.activeMode)
        .onAppear {
            store.markAsRead(chat)
            store.startListening(to: chat)
        }
        .onDisappear { store.stopListening() }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.sendMessage(messageText, in: chat)
        messageText = ""
    }

    private func scheduleMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let sendDate = max(scheduledDate, Date().addingTimeInterval(1))
        store.scheduleMessage(messageText, in: chat, for: sendDate)
        messageText = ""
        scheduledDate = Date().addingTimeInterval(900)
        isShowingScheduleOptions = false
    }

    private func toggleScheduleOptions() {
        scheduledDate = max(scheduledDate, Date().addingTimeInterval(900))
        isShowingScheduleOptions.toggle()
    }

    private func readReceiptText(for message: ChatMessage) -> String {
        message.readAt == nil ? "Delivered" : "Read"
    }

    private func scheduledTimeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
