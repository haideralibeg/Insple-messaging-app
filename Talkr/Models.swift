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
internal import Combine
import FirebaseFirestore 
import FirebaseAuth 

// 1. Made User Codable so we can save profiles to Firebase
struct User: Identifiable, Hashable, Codable {
    var id: String
    let name: String
    var displayName: String { name } 
    var avatarDetails: String? = nil
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

// MARK: - App State & Managers
class ChatStore: ObservableObject {
    @Published var chats: [Chat] = [] // Empty for now, will populate as you chat!
    @Published var contacts: [User] = [] // We will store REAL users here
    
    private let db = Firestore.firestore()
    private var activeListener: ListenerRegistration?
    
    // FETCH REAL USERS FROM DIRECTORY
    func fetchContacts() {
        db.collection("users").addSnapshotListener { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            let currentUserId = Auth.auth().currentUser?.uid ?? ""
            
            self.contacts = docs.compactMap { doc in
                guard let user = try? doc.data(as: User.self) else { return nil }
                // We hide "yourself" from the contacts list
                if user.id == currentUserId { return nil }
                return user
            }
        }
    }
    
    // GENERATE 1-ON-1 ROOM
    func getOrCreateChat(with partner: User) -> Chat {
        let currentUserId = Auth.auth().currentUser?.uid ?? "me"
        
        // Magic: Sort the two IDs alphabetically. 
        // Whether UserA taps UserB, or UserB taps UserA, the Room ID is EXACTLY the same!
        let roomId = [currentUserId, partner.id].sorted().joined(separator: "_")
        
        // If it's already in the inbox, open it
        if let existingChat = chats.first(where: { $0.id == roomId }) {
            return existingChat
        }
        
        // Otherwise, create a fresh chat
        let newChat = Chat(id: roomId, partner: partner, lastMessage: "Start of chat", timeAgo: "", isUnread: false, messages: [])
        
        // Put it in the Inbox so you can see it on the home screen
        DispatchQueue.main.async {
            self.chats.insert(newChat, at: 0)
        }
        
        return newChat
    }
    
    func markAsRead(_ chat: Chat) {
        if let idx = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[idx].isUnread = false
        }
    }
    
    func startListening(to chat: Chat) {
        stopListening()
        let messagesRef = db.collection("chats")
            .document(chat.id)
            .collection("messages")
            .order(by: "timestamp", descending: false)
        
        activeListener = messagesRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else { return }
            let currentUserId = Auth.auth().currentUser?.uid ?? ""
            
            let liveMessages = documents.compactMap { doc -> ChatMessage? in
                guard var msg = try? doc.data(as: ChatMessage.self) else { return nil }
                msg.isIncoming = (msg.senderId != currentUserId)
                return msg
            }
            
            DispatchQueue.main.async {
                if let idx = self.chats.firstIndex(where: { $0.id == chat.id }) {
                    if !liveMessages.isEmpty {
                        self.chats[idx].messages = liveMessages
                    }
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
        
        let newMessage = ChatMessage(id: UUID().uuidString, senderId: currentUserId, content: text, timestamp: Date(), isIncoming: false)
        
        do {
            try db.collection("chats").document(chat.id).collection("messages").document(newMessage.id).setData(from: newMessage)
            
            DispatchQueue.main.async {
                self.chats[idx].lastMessage = text
                self.chats[idx].timeAgo = "Now"
                let updatedChat = self.chats.remove(at: idx)
                self.chats.insert(updatedChat, at: 0)
            }
        } catch {
            print("Failed to save message: \(error)")
        }
    }
}

class ThemeManager: ObservableObject { }

class AuthService: ObservableObject {
    @Published var currentUser: User? = nil
    @Published var isAuthenticated: Bool = false
    private var authListener: AuthStateDidChangeListenerHandle?
    
    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if let user = user {
                // We use their Email or Phone as their display name for now
                let newUser = User(id: user.uid, name: user.email ?? user.phoneNumber ?? "Unknown")
                self?.currentUser = newUser
                self?.isAuthenticated = true
                
                // SAVE TO DIRECTORY SO OTHERS CAN FIND THEM!
                try? Firestore.firestore().collection("users").document(user.uid).setData(from: newUser)
            } else {
                self?.currentUser = nil
                self?.isAuthenticated = false
            }
        }
    }
    
    func logout() {
        try? Auth.auth().signOut()
    }
}
