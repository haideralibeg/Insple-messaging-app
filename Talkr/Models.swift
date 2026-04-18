import Foundation
internal import Combine
import FirebaseFirestore 

/*
 =========================================
 SUMMARY OF CHANGES MADE:
 =========================================
 1. Connected to Firebase: We imported `FirebaseFirestore` to talk to a real backend database.
 2. Made Messages "Codable": We added `Codable` to `ChatMessage`. This is the "Origami" step that folds our Swift message into a format the Firebase can store.
 3. Built the Send Message Function: We added the `sendMessage` function to `ChatStore`.
    - First, it updates the "Short-Term Memory" (the local array) so the UI updates instantly.
    - Second, it saves the message to "Long-Term Memory" (Firebase) inside a specific folder path: chats -> [Chat ID] -> messages -> [Message ID].
 =========================================
 */

struct User: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let avatarDetails: String? = nil
}

// 2. We added "Codable" here so it can be folded up and sent to Firebase
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

// Mock data for prototype
let mockMe = User(name: "Me")
let mockJohn = User(name: "John, Smith")
let mockKyle = User(name: "Kyle, Gordon")
let mockJean = User(name: "Jean, Lee")
let mockCasey = User(name: "Casey, Brown")
let mockTaylor = User(name: "Taylor, Morgan")
let mockChris = User(name: "Chris, Johnson")
let mockSam = User(name: "Sam, Taylor")
let mockAlex = User(name: "Alex, Guy")

let mockContacts: [User] = [mockJohn, mockKyle, mockJean, mockCasey, mockTaylor, mockChris, mockSam, mockAlex]

var mockChats: [Chat] = [
    Chat(partner: mockJohn, lastMessage: "Maybe next time though!", timeAgo: "10m", isUnread: true, messages: [
        ChatMessage(id: UUID(), senderId: mockMe.id, content: "Did you hear the news with AJ", timestamp: Date(), isIncoming: false),
        ChatMessage(id: UUID(), senderId: mockJohn.id, content: "No??", timestamp: Date(), isIncoming: true),
        ChatMessage(id: UUID(), senderId: mockJohn.id, content: "What happened?", timestamp: Date(), isIncoming: true),
        ChatMessage(id: UUID(), senderId: mockJohn.id, content: "Wait was it Sara?", timestamp: Date(), isIncoming: true),
        ChatMessage(id: UUID(), senderId: mockMe.id, content: "Nah not at all lmao", timestamp: Date(), isIncoming: false),
        ChatMessage(id: UUID(), senderId: mockMe.id, content: "it was something at the concert last night", timestamp: Date(), isIncoming: false),
        ChatMessage(id: UUID(), senderId: mockMe.id, content: "apparently they were giving out free shirts", timestamp: Date(), isIncoming: false),
        ChatMessage(id: UUID(), senderId: mockJohn.id, content: "Aw sick!", timestamp: Date(), isIncoming: true),
        ChatMessage(id: UUID(), senderId: mockJohn.id, content: "Yeah I would've gone but not my scene", timestamp: Date(), isIncoming: true),
        ChatMessage(id: UUID(), senderId: mockJohn.id, content: "Maybe next time though!", timestamp: Date(), isIncoming: true)
    ]),
    Chat(partner: mockKyle, lastMessage: "All good! Sorry I mis...", timeAgo: "1d", isUnread: false, messages: []),
    Chat(partner: mockJean, lastMessage: "Did you see that bird??", timeAgo: "2d", isUnread: true, messages: [])
]

class ChatStore: ObservableObject {
    @Published var chats: [Chat] = mockChats
    
    // This is our link to the Firebase
    private let db = Firestore.firestore()
    
    func markAsRead(_ chat: Chat) {
        if let idx = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[idx].isUnread = false
        }
    }
    
    func sendMessage(_ text: String, in chat: Chat) {
        guard let idx = chats.firstIndex(where: { $0.id == chat.id }) else { return }
        
        // 1. Create the new message
        let newMessage = ChatMessage(
            id: UUID(), // We give it a unique ID right away
            senderId: mockMe.id,
            content: text,
            timestamp: Date(),
            isIncoming: false
        )
        
        // 2. Save to Short-Term Memory (Updates UI instantly)
        chats[idx].messages.append(newMessage)
        chats[idx].lastMessage = text
        chats[idx].timeAgo = "Now"
        
        let updatedChat = chats.remove(at: idx)
        chats.insert(updatedChat, at: 0)
        
        // 3. Save to Long-Term Memory (Firebase)
        do {
            // We tell Firebase: Go to the "chats" -> find this chat's folder -> open the "messages" folder -> and put the  message inside!
            try db.collection("chats").document(chat.id.uuidString)
                .collection("messages").document(newMessage.id.uuidString)
                .setData(from: newMessage)
            
            print("Message successfully saved to Firebase!")
        } catch {
            print("Uh oh! Failed to save message: \(error.localizedDescription)")
        }
    }
}
