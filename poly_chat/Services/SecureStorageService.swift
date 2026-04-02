import Foundation

class SecureStorageService {
    private let serviceName = "com.polychat.app"

    func saveAPIKey(_ apiKey: String) -> Bool {
        guard let data = apiKey.data(using: .utf8) else { return false }
        return KeychainService.shared.save(service: serviceName, account: "apiKey", data: data)
    }

    func getAPIKey() -> String? {
        guard let data = KeychainService.shared.load(service: serviceName, account: "apiKey") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteAPIKey() -> Bool {
        return KeychainService.shared.delete(service: serviceName, account: "apiKey")
    }

    func saveEndpoint(_ endpoint: String) -> Bool {
        guard let data = endpoint.data(using: .utf8) else { return false }
        return KeychainService.shared.save(service: serviceName, account: "endpoint", data: data)
    }

    func getEndpoint() -> String? {
        guard let data = KeychainService.shared.load(service: serviceName, account: "endpoint") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteEndpoint() -> Bool {
        return KeychainService.shared.delete(service: serviceName, account: "endpoint")
    }

    func saveTavilyAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        return KeychainService.shared.save(service: serviceName, account: "tavilyAPIKey", data: data)
    }

    func getTavilyAPIKey() -> String? {
        guard let data = KeychainService.shared.load(service: serviceName, account: "tavilyAPIKey") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteTavilyAPIKey() -> Bool {
        return KeychainService.shared.delete(service: serviceName, account: "tavilyAPIKey")
    }
}
