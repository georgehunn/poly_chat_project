import Foundation

/// Default no-op implementation of `PremiumProvider` for the free open-source build.
/// All premium checks return false/empty, so the app runs fully without any premium package.
struct FreePremiumProvider: PremiumProvider {
    var isSubscribed: Bool { false }

    var availableFeatures: Set<PremiumFeature> { [] }

    func initialize() async {
        // No-op in free build
    }

    func syncConversations(_ conversations: [Conversation]) async throws {
        // No-op in free build
    }

    func hostedModelProvider() -> APIProviderConfig? {
        // No hosted models in free build — user provides their own
        nil
    }
}
