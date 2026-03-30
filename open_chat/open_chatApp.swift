import SwiftUI
import open_chat

@main
struct OpenChatApp: App {
    @StateObject private var chatManager = ChatManager()
    @StateObject private var modelManager = ModelManager()

    @AppStorage("darkMode") private var darkMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Clean up old PDF files when app launches
                    Task {
                        await PDFDocumentService.shared.cleanupOldPDFFiles()
                    }
                }
                .environmentObject(chatManager)
                .environmentObject(modelManager)
                .preferredColorScheme(darkMode ? .dark : .light)
        }
    }
}