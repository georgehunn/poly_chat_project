import SwiftUI

@main
struct OpenChatApp: App {
    @StateObject private var chatManager = ChatManager()
    @StateObject private var modelManager = ModelManager()

    @AppStorage("darkMode") private var darkMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(chatManager)
                .environmentObject(modelManager)
                .preferredColorScheme(darkMode ? .dark : .light)
        }
    }
}