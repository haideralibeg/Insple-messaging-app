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
    let name: String
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

    private lazy var db = Firestore.firestore()
    private let isPreview: Bool

    init(isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1") {
        self.isPreview = isPreview
    }
    private var activeListener: ListenerRegistration?

    func fetchContacts() {
        guard !isPreview else { return }
        db.collection("users").addSnapshotListener { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            let currentUserId = Auth.auth().currentUser?.uid ?? ""
            self.contacts = docs.compactMap { doc in
                guard let user = try? doc.data(as: User.self) else { return nil }
                return user.id == currentUserId ? nil : user
            }
            self.discoverChats()
        }
    }

    func discoverChats() {
        guard !isPreview else { return }
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        for contact in contacts {
            let roomId = [currentUserId, contact.id].sorted().joined(separator: "_")

            if chats.contains(where: { $0.id == roomId }) { continue }

            let ref = db.collection("chats").document(roomId).collection("messages")
                .order(by: "timestamp", descending: true)
                .limit(to: 1)

            ref.getDocuments { [weak self] snapshot, _ in
                guard let self,
                      let doc = snapshot?.documents.first,
                      let msg = try? doc.data(as: ChatMessage.self) else { return }   // no history -> skip, don't show

                DispatchQueue.main.async {
                    guard !self.chats.contains(where: { $0.id == roomId }) else { return }
                    let chat = Chat(id: roomId, partner: contact, lastMessage: msg.content, timeAgo: "", isUnread: false, messages: [])
                    self.chats.append(chat)
                }
            }
        }
    }

    func getOrCreateChat(with partner: User) -> Chat {
        if isPreview {
            if let chat = chats.first(where: { $0.partner.id == partner.id }) { return chat }
            let chat = Chat(id: "preview-\(partner.id)", partner: partner, lastMessage: "Start of chat", timeAgo: "Now", isUnread: false, messages: [])
            chats.insert(chat, at: 0)
            return chat
        }
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
        if let idx = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[idx].isUnread = false
        }
    }

    func startListening(to chat: Chat) {
        guard !isPreview else { return }
        stopListening()
        let ref = db.collection("chats").document(chat.id).collection("messages").order(by: "timestamp", descending: false)

        var receivedInitialSnapshot = false
        activeListener = ref.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let documents = snapshot?.documents else { return }
            let currentUserId = Auth.auth().currentUser?.uid ?? ""
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
        activeListener?.remove()
        activeListener = nil
    }

    func sendMessage(_ text: String, in chat: Chat) {
        if isPreview {
            guard let index = chats.firstIndex(where: { $0.id == chat.id }) else { return }
            chats[index].messages.append(ChatMessage(senderId: "preview-me", content: text, timestamp: Date(), isIncoming: false))
            chats[index].lastMessage = text
            chats[index].timeAgo = "Now"
            return
        }
        guard let idx = chats.firstIndex(where: { $0.id == chat.id }) else { return }
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        let msg = ChatMessage(id: UUID().uuidString, senderId: currentUserId, content: text, timestamp: Date(), isIncoming: false)

        do {
            try db.collection("chats").document(chat.id).collection("messages").document(msg.id).setData(from: msg)
            DispatchQueue.main.async {
                self.chats[idx].lastMessage = text
                self.chats[idx].timeAgo = "Now"
                let updated = self.chats.remove(at: idx)
                self.chats.insert(updated, at: 0)
            }
        } catch {
            print("Failed to save message: \(error)")
        }
    }
    
    func markMessagesAsRead(in chat: Chat) {
        guard !isPreview else { return }
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

    private let isPreview: Bool

    init(isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1") {
        self.isPreview = isPreview
        guard !isPreview else { return }
        AuthService.shared.$currentUser
            .compactMap { $0?.activeMode }
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in self?.activeMode = mode }
            .store(in: &cancellables)
    }

    func toggle() {
        let next = activeMode == "genz" ? "nostalgic" : "genz"
        activeMode = next
        if !isPreview { AuthService.shared.updateMode(next) }
    }

    func set(_ mode: String) {
        activeMode = mode
        if !isPreview { AuthService.shared.updateMode(mode) }
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

    private let isPreview: Bool

    init(isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1") {
        self.isPreview = isPreview
        guard !isPreview else { return }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user {
                let newUser = User(id: user.uid, name: user.displayName ?? user.email ?? user.phoneNumber ?? "Unknown")
                let ref = Firestore.firestore().collection("users").document(user.uid)
                ref.getDocument { [weak self] snapshot, _ in
                    guard Auth.auth().currentUser?.uid == user.uid else { return }
                    let savedMode = snapshot?.data()?["activeMode"] as? String
                    var profile = newUser
                    profile.activeMode = savedMode == "nostalgic" ? "nostalgic" : "genz"
                    DispatchQueue.main.async {
                        self?.currentUser = profile
                        self?.isAuthenticated = true
                    }
                    // Preserve existing preferences and other profile fields.
                    if snapshot?.exists == false {
                        try? ref.setData(from: profile, merge: true)
                    }
                }
            } else {
                self?.currentUser = nil
                self?.isAuthenticated = false
            }
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
        if isPreview {
            await MainActor.run { isAuthenticated = true }
            return
        }
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
        if isPreview {
            await MainActor.run { isAuthenticated = true }
            return
        }
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
        if isPreview {
            isAuthenticated = false
            screen = .login
            return
        }
        try? Auth.auth().signOut()
        screen = .login
    }

    // MARK: Update theme mode
    func updateMode(_ mode: String) {
        guard !isPreview else { return }
        guard let uid = currentUser?.id else { return }
        currentUser?.activeMode = mode
        Firestore.firestore().collection("users").document(uid).updateData(["activeMode": mode])
    }
}
