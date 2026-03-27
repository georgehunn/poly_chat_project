import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var chatManager: ChatManager
    @EnvironmentObject private var modelManager: ModelManager
    @State private var showingSettings = false
    @State private var showingModels = false
    @State private var showingModelSelection = false
    @State private var selectedConversationId: UUID?

    var body: some View {
        NavigationView {
            ChatListView(selectedConversationId: $selectedConversationId)
                .navigationBarTitle("Chats")
                .navigationBarItems(
                    leading: HStack {
                        Button(action: {
                            // Show model selection for new chat
                            showingModelSelection = true
                        }) {
                            Image(systemName: "square.and.pencil")
                        }

                        Button(action: {
                            showingModels = true
                        }) {
                            Image(systemName: "cpu")
                        }
                    },
                    trailing: Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                )
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
                .sheet(isPresented: $showingModels) {
                    NavigationView {
                        ModelsView(selectedModel: .constant(nil))
                            .environmentObject(modelManager)
                    }
                }
                .sheet(isPresented: $showingModelSelection) {
                    ModelSelectionView() { selectedModel in
                        let newConversation = chatManager.createNewConversation(model: selectedModel)
                        selectedConversationId = newConversation.id
                    }
                    .environmentObject(modelManager)
                    .environmentObject(chatManager)
                }

            // Empty state when no conversation is selected (this will be hidden when using NavigationLink)
            VStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("Select a conversation or start a new one")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            .navigationBarTitle("Chats")
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ChatManager())
            .environmentObject(ModelManager())
    }
}
