import Foundation

struct User: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let avatarDetails: String? = nil
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
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

// Mock data for prototype, will not be used in final product
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
        ChatMessage(senderId: mockMe.id, content: "Did you hear the news with AJ", timestamp: Date(), isIncoming: false),
        ChatMessage(senderId: mockJohn.id, content: "No??", timestamp: Date(), isIncoming: true),
        ChatMessage(senderId: mockJohn.id, content: "What happened?", timestamp: Date(), isIncoming: true),
        ChatMessage(senderId: mockJohn.id, content: "Wait was it Sara?", timestamp: Date(), isIncoming: true),
        ChatMessage(senderId: mockMe.id, content: "Nah not at all lmao", timestamp: Date(), isIncoming: false),
        ChatMessage(senderId: mockMe.id, content: "it was something at the concert last night", timestamp: Date(), isIncoming: false),
        ChatMessage(senderId: mockMe.id, content: "apparently they were giving out free shirts", timestamp: Date(), isIncoming: false),
        ChatMessage(senderId: mockJohn.id, content: "Aw sick!", timestamp: Date(), isIncoming: true),
        ChatMessage(senderId: mockJohn.id, content: "Yeah I would've gone but not my scene", timestamp: Date(), isIncoming: true),
        ChatMessage(senderId: mockJohn.id, content: "Maybe next time though!", timestamp: Date(), isIncoming: true)
    ]),
    Chat(partner: mockKyle, lastMessage: "All good! Sorry I mis...", timeAgo: "1d", isUnread: false, messages: []),
    Chat(partner: mockJean, lastMessage: "Did you see that bird??", timeAgo: "2d", isUnread: true, messages: [])
]

class ChatStore: ObservableObject {
    @Published var chats: [Chat] = mockChats
    
    func markAsRead(_ chat: Chat) {
        if let idx = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[idx].isUnread = false
        }
    }
}
