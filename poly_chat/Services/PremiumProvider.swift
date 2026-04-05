import Foundation

/// Protocol defining the boundary between the free open-source core and optional premium features.
///
/// The default implementation (`FreePremiumProvider`) is a no-op that ships with the open-source build.
/// A private `PolyChat_Premium` Swift package can provide a real implementation that integrates
/// StoreKit subscriptions, cloud sync, hosted model endpoints, etc.
///
/// Inject a concrete provider at app launch via `PremiumProvider.current`.
protocol PremiumProvider {
    /// Whether the user has an active premium subscription.
    var isSubscribed: Bool { get }

    /// Premium feature flags — check these to conditionally show UI or enable capabilities.
    var availableFeatures: Set<PremiumFeature> { get }

    /// Called once at app launch to set up any premium services (StoreKit listeners, sync, etc.).
    func initialize() async

    /// Cloud sync: upload conversations to the user's cloud storage.
    func syncConversations(_ conversations: [Conversation]) async throws

    /// Returns a premium API endpoint config if the user is subscribed to hosted models.
    /// Returns `nil` if not available, and the app falls back to the user's own provider config.
    func hostedModelProvider() -> APIProviderConfig?
}

/// Features that can be unlocked via premium. Used to gate UI elements.
enum PremiumFeature: String, Hashable {
    case cloudSync
    case hostedModels
    case premiumWebSearch
    case advancedWorkflows
}

// MARK: - Global access point

enum Premium {
    /// The active premium provider. Defaults to `FreePremiumProvider`.
    /// Set this to a real implementation at app launch if the premium package is linked.
    static var current: PremiumProvider = FreePremiumProvider()
}
