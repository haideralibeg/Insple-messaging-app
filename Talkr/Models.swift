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
    var id: String = UUID().uuidString
    let senderId: String
    let content: String
    let timestamp: Date
    var isIncoming: Bool
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

    func fetchContacts() {
        db.collection("users").addSnapshotListener { snapshot, error in
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
        if let idx = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[idx].isUnread = false
        }
    }

    func startListening(to chat: Chat) {
        stopListening()
        let ref = db.collection("chats").document(chat.id).collection("messages").order(by: "timestamp", descending: false)

        activeListener = ref.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let documents = snapshot?.documents else { return }
            let currentUserId = Auth.auth().currentUser?.uid ?? ""
            let liveMessages = documents.compactMap { doc -> ChatMessage? in
                guard var msg = try? doc.data(as: ChatMessage.self) else { return nil }
                msg.isIncoming = msg.senderId != currentUserId
                return msg
            }
            DispatchQueue.main.async {
                if let idx = self.chats.firstIndex(where: { $0.id == chat.id }), !liveMessages.isEmpty {
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

    // MARK: Theme Colors

    // Gen Z = dark mode, Nostalgic = light mode
    var backgroundColor: Color {
        activeMode == "genz" ? Color(red: 0.07, green: 0.07, blue: 0.07) : .white
    }
    var primaryColor: Color {
        activeMode == "genz" ? .white : .black
    }
    var primaryTextColor: Color {
        activeMode == "genz" ? .black : .white
    }
    var secondaryTextColor: Color {
        activeMode == "genz" ? .white : .black
    }
    var subtleColor: Color {
        activeMode == "genz" ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color(.systemGray5)
    }
    var outgoingBubbleColor: Color {
        activeMode == "genz" ? Color(red: 0.4, green: 0.2, blue: 0.9) : Color(red: 0.9, green: 0.45, blue: 0.0)
    }
    var incomingBubbleColor: Color {
        activeMode == "genz" ? Color(red: 0.18, green: 0.18, blue: 0.18) : Color(.systemGray5)
    }
    var unreadDotColor: Color {
        activeMode == "genz" ? Color(red: 0.4, green: 0.2, blue: 0.9) : .red
    }
    var tabFont: Font { .title2 }

    var label1: String { "Gen Z" }
    var label2: String { "Nostalgic" }
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

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user {
                let newUser = User(id: user.uid, name: user.displayName ?? user.email ?? user.phoneNumber ?? "Unknown")
                self?.currentUser = newUser
                self?.isAuthenticated = true
                try? Firestore.firestore().collection("users").document(user.uid).setData(from: newUser)
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
