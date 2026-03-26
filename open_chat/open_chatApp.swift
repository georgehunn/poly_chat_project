import SwiftUI

@main
struct OpenChatApp: App {
    @StateObject private var chatManager = ChatManager()
    @StateObject private var modelManager = ModelManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(chatManager)
                .environmentObject(modelManager)
                .preferredColorScheme(getPreferredColorScheme())
        }
    }

    private func getPreferredColorScheme() -> ColorScheme? {
        let darkModeEnabled = UserDefaults.standard.bool(forKey: "darkMode")
        return darkModeEnabled ? .dark : .light
    }
}