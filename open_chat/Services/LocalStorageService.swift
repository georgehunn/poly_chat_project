import Foundation

class LocalStorageService {
    private let conversationsKey = "OpenChatConversations"

    func saveConversations(_ conversations: [Conversation]) {
        do {
            let data = try JSONEncoder().encode(conversations)
            // For simplicity, we'll store as base64 encoded string
            // In production, implement proper encryption
            let base64String = data.base64EncodedString()
            UserDefaults.standard.set(base64String, forKey: conversationsKey)
        } catch {
            print("Error encoding conversations: \(error)")
        }
    }

    func loadConversations() -> [Conversation] {
        guard let base64String = UserDefaults.standard.string(forKey: conversationsKey),
              let data = Data(base64Encoded: base64String) else {
            return []
        }

        do {
            let conversations = try JSONDecoder().decode([Conversation].self, from: data)
            return conversations
        } catch {
            print("Error decoding conversations: \(error)")
            return []
        }
    }

    func deleteAllData() {
        UserDefaults.standard.removeObject(forKey: conversationsKey)
    }
}