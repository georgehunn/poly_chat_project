import SwiftUI
import poly_chat

@main
struct PolyChatApp: App {
    @StateObject private var chatManager = ChatManager()
    @StateObject private var modelManager = ModelManager()

    @AppStorage("darkMode") private var darkMode = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Task {
                        // Initialize premium provider (no-op in free build)
                        await Premium.current.initialize()
                        // Clean up old PDF files when app launches
                        await PDFDocumentService.shared.cleanupOldPDFFiles()
                    }
                }
                .environmentObject(chatManager)
                .environmentObject(modelManager)
                .preferredColorScheme(darkMode ? .dark : .light)
        }
    }
}