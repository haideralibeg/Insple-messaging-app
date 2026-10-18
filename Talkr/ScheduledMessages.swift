import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ScheduledMessage: Identifiable, Codable, Equatable {
    let id: String
    let chatId: String
    let senderId: String
    let content: String
    let scheduledFor: Date
}

@MainActor
@Observable
final class ScheduledMessageStore {
    private(set) var messages: [ScheduledMessage] = []
    private var listener: ListenerRegistration?
    private var userID: String?
    var errorMessage: String?

    func observe(userID: String?) {
        listener?.remove()
        listener = nil
        self.userID = userID
        messages = []
        errorMessage = nil
        guard LocalDevelopment.usesEmulators, let userID else { return }
        listener = Firestore.firestore().collection("scheduledMessages")
            .whereField("senderId", isEqualTo: userID)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.userID == userID,
                          Auth.auth().currentUser?.uid == userID else { return }
                    if let error { self.errorMessage = error.localizedDescription; return }
                    self.messages = snapshot?.documents.compactMap {
                        try? $0.data(as: ScheduledMessage.self)
                    }.sorted { $0.scheduledFor < $1.scheduledFor } ?? []
                }
            }
    }

    func schedule(_ text: String, in chat: Chat, for date: Date) async -> Bool {
        guard LocalDevelopment.usesEmulators else {
            errorMessage = "Scheduled delivery is currently available in Talkr Local."
            return false
        }
        guard let senderID = Auth.auth().currentUser?.uid, senderID == userID else { return false }
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, content.count <= 10000, date > .now else {
            errorMessage = "Enter a message of up to 10,000 characters and choose a future time."
            return false
        }
        let id = UUID().uuidString
        do {
            // Wait for a server acknowledgement before clearing the draft.
            try await Firestore.firestore().collection("scheduledMessages").document(id).setData([
                "id": id, "chatId": chat.id, "senderId": senderID,
                "content": content, "scheduledFor": Timestamp(date: date)
            ])
            return Auth.auth().currentUser?.uid == senderID
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func cancel(_ message: ScheduledMessage) async {
        guard message.senderId == Auth.auth().currentUser?.uid else { return }
        do {
            try await Firestore.firestore().collection("scheduledMessages").document(message.id).delete()
        } catch { errorMessage = error.localizedDescription }
    }
}

struct ScheduleMessageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @Environment(ScheduledMessageStore.self) private var scheduled
    @State private var scheduledDate = Date().addingTimeInterval(900)
    @State private var isSaving = false
    let content: String
    let schedule: (Date) async -> Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(content).frame(maxWidth: .infinity, alignment: .leading)
                    DatePicker("Send at", selection: $scheduledDate, in: Date()...,
                               displayedComponents: [.date, .hourAndMinute])
                    Button("In 1 minute") { scheduledDate = Date().addingTimeInterval(60) }
                    if theme.isNostalgic {
                        Button("Schedule message", action: save)
                            .buttonStyle(RetroButtonStyle())
                            .disabled(isSaving)
                    } else {
                        Button("Schedule message", action: save)
                            .buttonStyle(.borderedProminent)
                            .tint(theme.outgoingBubbleColor)
                            .disabled(isSaving)
                    }
                    if isSaving { ProgressView("Saving schedule…") }
                }
                .padding()
            }
            .background(theme.backgroundColor)
            .foregroundStyle(theme.secondaryTextColor)
            .navigationTitle("Send later")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }.disabled(isSaving)
                }
            }
        }
        .preferredColorScheme(theme.isNostalgic ? .light : .dark)
        .interactiveDismissDisabled(isSaving)
        .alert("Message could not be scheduled", isPresented: Binding(
            get: { scheduled.errorMessage != nil },
            set: { if !$0 { scheduled.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { scheduled.errorMessage = nil }
        } message: { Text(scheduled.errorMessage ?? "") }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            if await schedule(scheduledDate) { dismiss() }
            isSaving = false
        }
    }
}

struct ScheduledMessageRow: View {
    @EnvironmentObject private var theme: ThemeManager
    let message: ScheduledMessage
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.content)
            Label {
                Text("Scheduled \(message.scheduledFor.formatted(date: .abbreviated, time: .shortened))")
            } icon: { Image(systemName: "clock") }
            .font(.caption)
            Button("Cancel scheduled message", role: .destructive, action: cancel)
                .font(.caption)
        }
        .font(theme.isNostalgic ? .system(.subheadline, design: .monospaced) : .subheadline)
        .foregroundStyle(theme.secondaryTextColor)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.subtleColor)
        .overlay(Rectangle().stroke(theme.secondaryTextColor.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4])))
        .accessibilityElement(children: .contain)
    }
}
