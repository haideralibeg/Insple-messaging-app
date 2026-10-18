/*
 =========================================
 FILE: Models.swift
 
 SUMMARY:
 Contains the core data structures (User, Chat, ChatMessage) and the primary
 state managers (ChatStore, AuthService) that handle the connection between the
 SwiftUI interface and the Firebase backend.
 
 CHANGES IN THIS SESSION:
 - Made `User` and `ChatMessage` Codable to save to Firebase.
 - Changed `id` fields from UUID to String to match Firebase ID constraints.
 - Added `fetchContacts()` to pull real users from the Firestore directory.
 - Added `getOrCreateChat()` to dynamically generate unique 1-on-1 room IDs based on User UIDs.
 - Implemented Firestore `SnapshotListeners` for real-time two-way syncing.
 - Wired `AuthService` directly to Firebase Authentication for live session tracking.
 =========================================
 */

import Foundation
import SwiftUI
internal import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - Onboarding Screen
enum OnboardingScreen {
    case login
    case signUpPhone
    case signUpOTP
    case signUpPassword
}

// MARK: - Models
struct User: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var displayName: String { name }
    var avatarDetails: String? = nil
    var activeMode: String = "genz"  // "genz" | "nostalgic"
}

struct ChatMessage: Identifiable, Hashable, Codable {
    var id: String
    let senderId: String
    let content: String
    let timestamp: Date
    var isIncoming: Bool
    var isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id, senderId, content, timestamp, isIncoming, isRead
    }

    init(id: String = UUID().uuidString, senderId: String, content: String,
         timestamp: Date, isIncoming: Bool, isRead: Bool = false) {
        self.id = id
        self.senderId = senderId
        self.content = content
        self.timestamp = timestamp
        self.isIncoming = isIncoming
        self.isRead = isRead
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        senderId = try c.decode(String.self, forKey: .senderId)
        content = try c.decode(String.self, forKey: .content)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        isIncoming = try c.decodeIfPresent(Bool.self, forKey: .isIncoming) ?? false
        isRead = try c.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
    }
}

struct Chat: Identifiable, Hashable {
    var id: String
    let partner: User
    var lastMessage: String
    var timeAgo: String
    var isUnread: Bool
    var messages: [ChatMessage]
}

// MARK: - ChatStore
class ChatStore: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var contacts: [User] = []

    private let db = Firestore.firestore()
    private var activeListener: ListenerRegistration?
    private var listeningTask: Task<Void, Never>?
    private var activeChatID: String?
    private var inboxListener: ListenerRegistration?
    private var contactsListener: ListenerRegistration?
    @Published var errorMessage: String?

    func observeInbox(userID: String?) {
        inboxListener?.remove()
        contactsListener?.remove()
        stopListening()
        chats = []
        contacts = []
        guard let userID else { return }
        inboxListener = db.collection("chats")
            .whereField("participants", arrayContains: userID)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, Auth.auth().currentUser?.uid == userID else { return }
                    if let error { self.errorMessage = error.localizedDescription; return }
                    guard let documents = snapshot?.documents else { return }
                    self.chats = documents.compactMap { document in
                        let data = document.data()
                        guard let members = data["participants"] as? [String],
                              let partnerID = members.first(where: { $0 != userID }) else { return nil }
                        let names = data["names"] as? [String: String] ?? [:]
                        let previous = self.chats.first { $0.id == document.documentID }
                        let timestamp = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .now
                        return Chat(
                            id: document.documentID,
                            partner: User(id: partnerID, name: names[partnerID] ?? previous?.partner.name ?? "Talkr user"),
                            lastMessage: data["lastMessage"] as? String ?? "",
                            timeAgo: timestamp.formatted(date: .omitted, time: .shortened),
                            isUnread: (data["unreadFor"] as? [String] ?? []).contains(userID),
                            messages: previous?.messages ?? []
                        )
                    }.sorted { first, second in
                        let dates = Dictionary(uniqueKeysWithValues: documents.map {
                            ($0.documentID, ($0.data()["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast)
                        })
                        return (dates[first.id] ?? .distantPast) > (dates[second.id] ?? .distantPast)
                    }
                }
            }
    }

    func fetchContacts() {
        contactsListener?.remove()
        contactsListener = db.collection("users").addSnapshotListener { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            let currentUserId = Auth.auth().currentUser?.uid ?? ""
            self.contacts = docs.compactMap { doc in
                guard let user = try? doc.data(as: User.self) else { return nil }
                return user.id == currentUserId ? nil : user
            }
        }
    }

    func getOrCreateChat(with partner: User) -> Chat {
        let currentUserId = Auth.auth().currentUser?.uid ?? "me"
        let roomId = [currentUserId, partner.id].sorted().joined(separator: "_")

        if let existing = chats.first(where: { $0.id == roomId }) {
            return existing
        }

        let newChat = Chat(id: roomId, partner: partner, lastMessage: "Start of chat", timeAgo: "", isUnread: false, messages: [])
        DispatchQueue.main.async { self.chats.insert(newChat, at: 0) }
        return newChat
    }

    func markAsRead(_ chat: Chat) {
        if let idx = chats.firstIndex(where: { $0.id == chat.id }), chats[idx].isUnread {
            chats[idx].isUnread = false
            if let userID = Auth.auth().currentUser?.uid {
                db.collection("chats").document(chat.id)
                    .updateData(["unreadFor": FieldValue.arrayRemove([userID])])
            }
        }
    }

    func startListening(to chat: Chat) {
        stopListening()
        guard let userID = Auth.auth().currentUser?.uid else { return }
        activeChatID = chat.id
        listeningTask = Task { [weak self] in
            guard let self else { return }
            do {
                // Save membership before reading messages, including brand-new conversations.
                // Merge preserves existing message summaries and read state.
                try await self.db.collection("chats").document(chat.id).setData([
                    "participants": [userID, chat.partner.id].sorted(),
                    "names": [userID: AuthService.shared.currentUser?.name ?? "Talkr user",
                              chat.partner.id: chat.partner.name]
                ], merge: true)
                guard !Task.isCancelled, self.activeChatID == chat.id,
                      Auth.auth().currentUser?.uid == userID else { return }
                self.attachMessageListener(to: chat, userID: userID)
            } catch {
                guard !Task.isCancelled, Auth.auth().currentUser?.uid == userID else { return }
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func attachMessageListener(to chat: Chat, userID: String) {
        if !chats.contains(where: { $0.id == chat.id }) { chats.append(chat) }
        let ref = db.collection("chats").document(chat.id).collection("messages").order(by: "timestamp", descending: false)
        var receivedInitialSnapshot = false
        activeListener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self, self.activeChatID == chat.id,
                  Auth.auth().currentUser?.uid == userID else { return }
            if let error { self.errorMessage = error.localizedDescription; return }
            guard let documents = snapshot?.documents else { return }
            let currentUserId = userID
            let liveMessages = documents.compactMap { doc -> ChatMessage? in
                guard var msg = try? doc.data(as: ChatMessage.self) else { return nil }
                msg.isIncoming = msg.senderId != currentUserId
                return msg
            }
            let shouldChime = receivedInitialSnapshot && snapshot?.documentChanges.contains(where: {
                $0.type == .added && ($0.document.data()["senderId"] as? String) != currentUserId
            }) == true
            receivedInitialSnapshot = true
            DispatchQueue.main.async {
                guard self.activeChatID == chat.id, Auth.auth().currentUser?.uid == userID else { return }
                if shouldChime, ThemeManager.shared.isNostalgic {
                    NostalgicSounds.shared.play(.received)
                }
                if let idx = self.chats.firstIndex(where: { $0.id == chat.id }) {
                    self.chats[idx].messages = liveMessages
                }
            }
        }
    }

    func stopListening() {
        activeChatID = nil
        listeningTask?.cancel()
        listeningTask = nil
        activeListener?.remove()
        activeListener = nil
    }

    func sendMessage(_ text: String, in chat: Chat) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let msg = ChatMessage(id: UUID().uuidString, senderId: currentUserId, content: text, timestamp: Date(), isIncoming: false)

        do {
            let room = db.collection("chats").document(chat.id)
            let batch = db.batch()
            batch.setData([
                "participants": [currentUserId, chat.partner.id].sorted(),
                "names": [currentUserId: AuthService.shared.currentUser?.name ?? "Talkr user", chat.partner.id: chat.partner.name],
                "lastMessage": text,
                "updatedAt": FieldValue.serverTimestamp(),
                "unreadFor": [chat.partner.id]
            ], forDocument: room, merge: true)
            try batch.setData(from: msg, forDocument: room.collection("messages").document(msg.id))
            batch.commit { [weak self] error in
                if let error {
                    Task { @MainActor in self?.errorMessage = error.localizedDescription }
                }
            }
            // The inbox listener updates ordering and summaries after this write.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func markMessagesAsRead(in chat: Chat) {
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        let unread = chat.messages.filter { $0.senderId != currentUserId && !$0.isRead }
        guard !unread.isEmpty else { return }

        let batch = db.batch()
        let messagesRef = db.collection("chats").document(chat.id).collection("messages")
        for msg in unread {
            batch.updateData(["isRead": true], forDocument: messagesRef.document(msg.id))
        }
        batch.commit { error in
            if let error = error {
                print("Failed to mark messages as read: \(error)")
            }
        }
    }
}

// MARK: - ThemeManager
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var activeMode: String = "genz"  // "genz" | "nostalgic"

    private var cancellables = Set<AnyCancellable>()

    private init() {
        AuthService.shared.$currentUser
            .compactMap { $0?.activeMode }
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in self?.activeMode = mode }
            .store(in: &cancellables)
    }

    func toggle() {
        let next = activeMode == "genz" ? "nostalgic" : "genz"
        activeMode = next
        AuthService.shared.updateMode(next)
    }

    func set(_ mode: String) {
        activeMode = mode
        AuthService.shared.updateMode(mode)
    }

    var isNostalgic: Bool { activeMode == "nostalgic" }

    // MARK: Theme Colors

    // Gen Z uses a dark canvas; Nostalgic uses desktop messenger chrome.
    var backgroundColor: Color {
        activeMode == "genz" ? Color(red: 0.07, green: 0.07, blue: 0.07) : RetroPalette.desktop
    }
    var primaryColor: Color {
        activeMode == "genz" ? .white : RetroPalette.navy
    }
    var primaryTextColor: Color {
        activeMode == "genz" ? .black : .white
    }
    var secondaryTextColor: Color {
        activeMode == "genz" ? .white : RetroPalette.ink
    }
    var subtleColor: Color {
        activeMode == "genz" ? Color(red: 0.2, green: 0.2, blue: 0.2) : RetroPalette.panel
    }
    var outgoingBubbleColor: Color {
        activeMode == "genz" ? Color(red: 0.4, green: 0.2, blue: 0.9) : RetroPalette.navy
    }
    var incomingBubbleColor: Color {
        activeMode == "genz" ? Color(red: 0.18, green: 0.18, blue: 0.18) : RetroPalette.panel
    }
    var unreadDotColor: Color {
        activeMode == "genz" ? Color(red: 0.4, green: 0.2, blue: 0.9) : .red
    }
    var tabFont: Font { .title2 }

    var label1: String { "Gen Z" }
    var label2: String { "Nostalgic" }
    var readReceiptSeenColor: Color {
        activeMode == "genz" ? primaryColor : .blue
    }
}

// MARK: - AuthService
class AuthService: ObservableObject {
    static let shared = AuthService()  // singleton for ThemeManager access
    // Session state
    @Published var currentUser: User? = nil
    @Published var isAuthenticated: Bool = false

    // Onboarding state
    @Published var screen: OnboardingScreen = .login
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var authListener: AuthStateDidChangeListenerHandle?
    private var pendingEmail: String = ""
    private var pendingDisplayName: String = ""

    var isCompletingPhoneSignIn = false

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor in
                guard let self, !self.isCompletingPhoneSignIn else { return }
                await self.refreshSession()
            }
        }
    }

    func refreshSession() async {
        guard let user = Auth.auth().currentUser else {
            currentUser = nil
            isAuthenticated = false
            return
        }
        do {
            let ref = Firestore.firestore().collection("users").document(user.uid)
            let snapshot = try await ref.getDocument()
            guard Auth.auth().currentUser?.uid == user.uid else { return }
            // A phone number is private account data, not a public display name.
            var profile = User(id: user.uid, name: snapshot.data()?["name"] as? String ?? user.displayName ?? "Talkr user")
            profile.activeMode = snapshot.data()?["activeMode"] as? String == "nostalgic" ? "nostalgic" : "genz"
            if !snapshot.exists || snapshot.data()?["activeMode"] == nil {
                try ref.setData(from: profile, merge: true)
            }
            currentUser = profile
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Navigation
    func goToSignUp() {
        errorMessage = nil
        screen = .signUpPhone
    }

    func goBackToLogin() {
        errorMessage = nil
        screen = .login
    }

    func goBackToOTP() {
        errorMessage = nil
        screen = .signUpOTP
    }

    // MARK: Login
    func login(email: String, password: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        defer { Task { await MainActor.run { self.isLoading = false } } }
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    // MARK: Sign-up Step 1 — Email + display name (skip OTP, go straight to password)
    func signUpSendOTP(email: String, displayName: String) async {
        await MainActor.run {
            self.pendingEmail = email
            self.pendingDisplayName = displayName
            self.screen = .signUpPassword
        }
    }

    // MARK: Sign-up Step 2 — Verify OTP (unused but kept so OnboardingView compiles)
    func signUpVerifyOTP(code: String) {
        screen = .signUpPassword
    }

    // MARK: Sign-up Step 3 — Create account + send verification email
    func signUpCreateAccount(password: String, confirmPassword: String) async {
        guard password == confirmPassword else {
            await MainActor.run { errorMessage = "Passwords do not match." }
            return
        }
        await MainActor.run { isLoading = true; errorMessage = nil }
        defer { Task { await MainActor.run { self.isLoading = false } } }
        do {
            let result = try await Auth.auth().createUser(withEmail: pendingEmail, password: password)
            let req = result.user.createProfileChangeRequest()
            req.displayName = pendingDisplayName
            try await req.commitChanges()
            try await result.user.sendEmailVerification()
            // authListener above will automatically set isAuthenticated = true
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    // MARK: Logout
    func logout() {
        try? Auth.auth().signOut()
        screen = .login
    }

    // MARK: Update theme mode
    func updateMode(_ mode: String) {
        guard let uid = currentUser?.id else { return }
        currentUser?.activeMode = mode
        Firestore.firestore().collection("users").document(uid).updateData(["activeMode": mode])
    }
}
