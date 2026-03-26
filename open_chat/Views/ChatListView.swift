import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var chatManager: ChatManager
    @Binding var selectedConversationId: UUID?

    init(selectedConversationId: Binding<UUID?>) {
        _selectedConversationId = selectedConversationId
    }

    var body: some View {
        List {
            ForEach(chatManager.conversations) { conversation in
                NavigationLink(
                    destination: ChatView(conversationId: conversation.id),
                    tag: conversation.id,
                    selection: $selectedConversationId
                ) {
                    ChatRowView(conversation: conversation, isSelected: conversation.id == selectedConversationId)
                }
                .buttonStyle(PlainButtonStyle()) // This makes it look like a regular list row
            }
            .onDelete(perform: deleteConversations)
        }
        .refreshable {
            // Refresh conversations
        }
    }

    private func deleteConversations(offsets: IndexSet) {
        // Delete conversations at offsets
        for index in offsets {
            let conversation = chatManager.conversations[index]
            chatManager.deleteConversation(conversation)
        }
    }
}

struct ChatRowView: View {
    let conversation: Conversation
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Text(conversation.title)
                .font(.headline)
            Text(conversation.lastMessage ?? "New conversation")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}

struct ChatListView_Previews: PreviewProvider {
    @State static var selectedId: UUID? = nil

    static var previews: some View {
        ChatListView(selectedConversationId: $selectedId)
            .environmentObject(ChatManager())
    }
}