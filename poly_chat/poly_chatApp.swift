import SwiftUI
import poly_chat

@main
struct PolyChatApp: App {
    @StateObject private var chatManager = ChatManager()
    @StateObject private var modelManager = ModelManager()

    @AppStorage("darkMode") private var darkMode = true
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Apply analytics default: ON for new installs, OFF for existing users
        if !UserDefaults.standard.bool(forKey: "analyticsDefaultApplied") {
            let hasConversations = LocalStorageService().loadConversations().count > 0
            UserDefaults.standard.set(!hasConversations, forKey: "analyticsEnabled")
            UserDefaults.standard.set(true, forKey: "analyticsDefaultApplied")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    CrashReporter.install()
                    AnalyticsService.shared.checkForPendingCrashReport()
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
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .background {
                        AnalyticsService.shared.onBackground()
                    }
                }
        }
    }
}