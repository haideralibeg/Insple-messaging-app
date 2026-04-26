import Foundation
import Combine
import FirebaseFirestore

// MARK: - Firestore User Model (used by AuthService)
struct TalkrUser: Codable, Identifiable {
    @DocumentID var id: String?
    var phoneNumber: String
    var displayName: String
    var activeMode:  String      // "genz" | "nostalgic"
    var createdAt:   Timestamp
}

// MARK: - UI Models (used by ChatStore and Views)
struct User: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let avatarDetails: String? = nil
}

struct ChatMessage: Identifiable, Hashable, Codable {
    let id: UUID
    let senderId: UUID
    let content: String
    let timestamp: Date
    let isIncoming: Bool
}

struct Chat: Identifiable, Hashable {
    let id = UUID()
    let partner: User
    var lastMessage: String
    var timeAgo: String
    var isUnread: Bool
    var messages: [ChatMessage]
}

// MARK: - Mock Data (kept for UI demo purposes)
let mockMe    = User(name: "Me")
let mockJohn  = User(name: "John, Smith")
let mockKyle  = User(name: "Kyle, Gordon")
let mockJean  = User(name: "Jean, Lee")
let mockCasey = User(name: "Casey, Brown")
let mockTaylor = User(name: "Taylor, Morgan")
let mockChris = User(name: "Chris, Johnson")
let mockSam   = User(name: "Sam, Taylor")
let mockAlex  = User(name: "Alex, Guy")

let mockContacts: [User] = [
    mockJohn, mockKyle, mockJean, mockCasey,
    mockTaylor, mockChris, mockSam, mockAlex
]

var mockChats: [Chat] = [
    Chat(partner: mockJohn, lastMessage: "Maybe next time though!", timeAgo: "10m", isUnread: true, messages: [
        ChatMessage(id: UUID(), senderId: mockMe.id,   content: "Did you hear the news with AJ",               timestamp: Date(), isIncoming: false),
        ChatMessage(id: UUID(), senderId: mockJohn.id, content: "No??",                                         timestamp: Date(), isIncoming: true),
        ChatMessage(id: UUID(), senderId: mockJohn.id, content: "What happened?",                               timestamp: Date(), isIncoming: true),
        ChatMessage(id: UUID(), senderId: mockJohn.id, content: "Wait was it Sara?",                            timestamp: Date(), isIncoming: true),
        ChatMessage(id: UUID(), senderId: mockMe.id,   content: "Nah not at all lmao",                         timestamp: Date(), isIncoming: false),
        ChatMessage(id: UUID(), senderId: mockMe.id,   content: "it was something at the concert last night",   timestamp: Date(), isIncoming: false),
        ChatMessage(id: UUID(), senderId: mockMe.id,   content: "apparently they were giving out free shirts",  timestamp: Date(), isIncoming: false),
        ChatMessage(id: UUID(), senderId: mockJohn.id, content: "Aw sick!",                                     timestamp: Date(), isIncoming: true),
        ChatMessage(id: UUID(), senderId: mockJohn.id, content: "Yeah I would've gone but not my scene",        timestamp: Date(), isIncoming: true),
        ChatMessage(id: UUID(), senderId: mockJohn.id, content: "Maybe next time though!",                      timestamp: Date(), isIncoming: true)
    ]),
    Chat(partner: mockKyle, lastMessage: "All good! Sorry I mis...", timeAgo: "1d", isUnread: false, messages: []),
    Chat(partner: mockJean, lastMessage: "Did you see that bird??",   timeAgo: "2d", isUnread: true,  messages: [])
]

// MARK: - ChatStore
class ChatStore: ObservableObject {
    @Published var chats: [Chat] = mockChats

    private let db = Firestore.firestore()
    
    // Update chat status with DB
    private func updateMessages(_ messages: [ChatMessage], for chat: Chat) {
        guard let idx = chats.firstIndex(where: { $0.id == chat.id }) else { return }
            chats[idx].messages = messages
    }
    
    // listen for new messages from DB, called when opening a chat
    func listenForMessages(in chat: Chat){
        db.collection("chats")
            .document(chat.id.uuidString)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener{ [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                do {
                    let messages = try documents.compactMap {
                        try $0.data(as: ChatMessage.self)
                    }
                    
                    DispatchQueue.main.async {
                        self?.updateMessages(messages, for: chat)
                    }
                } catch{
                    print("Decoding error: \(error)")
                }
            }
    }
    
    func markAsRead(_ chat: Chat) {
        if let idx = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[idx].isUnread = false
        }
    }
    
    func sendMessage(_ text: String, in chat: Chat) {
        guard let idx = chats.firstIndex(where: { $0.id == chat.id }) else { return }

        let newMessage = ChatMessage(
            id: UUID(),
            senderId: mockMe.id,
            content: text,
            timestamp: Date(),
            isIncoming: false
        )

        // Update local state instantly
        chats[idx].messages.append(newMessage)
        chats[idx].lastMessage = text
        chats[idx].timeAgo = "Now"

        // Bubble conversation to top of inbox
        let updated = chats.remove(at: idx)
        chats.insert(updated, at: 0)

        // Persist to Firebase
        do {
            try db.collection("chats")
                  .document(chat.id.uuidString)
                  .collection("messages")
                  .document(newMessage.id.uuidString)
                  .setData(from: newMessage)
        } catch {
            print("Failed to save message: \(error.localizedDescription)")
        }
    }
}
