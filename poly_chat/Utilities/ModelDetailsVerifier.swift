import Foundation

/// Utility functions for verifying the model details implementation
class ModelDetailsVerifier {

    /// Verifies that the model details JSON file can be loaded and parsed
    /// - Returns: True if the file loads successfully, false otherwise
    static func verifyModelDetailsFile() -> Bool {
        guard let path = Bundle.main.path(forResource: "model_details", ofType: "json") else {
            print("❌ model_details.json not found in bundle")
            return false
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let models = json?["models"] as? [[String: Any]] else {
                print("❌ Invalid format in model details JSON")
                return false
            }

            print("✅ Successfully loaded model details JSON with \(models.count) models")

            // Check if we have some expected models
            let modelNames = models.compactMap { $0["name"] as? String }
            let hasLlama3 = modelNames.contains("llama3")
            let hasMistral = modelNames.contains("mistral")

            if hasLlama3 {
                print("✅ Found llama3 model in JSON")
            } else {
                print("⚠️ llama3 model not found in JSON")
            }

            if hasMistral {
                print("✅ Found mistral model in JSON")
            } else {
                print("⚠️ mistral model not found in JSON")
            }

            return true
        } catch {
            print("❌ Error reading or parsing model details JSON: \(error)")
            return false
        }
    }

    /// Tests loading specific model details
    /// - Parameter modelName: The name of the model to test
    /// - Returns: True if model details can be loaded, false otherwise
    static func testModelDetailsLoading(modelName: String) -> Bool {
        // This would normally use the ModelManager's loadModelDetailsFromLocalJSON method
        // For now, we'll just verify the file can be accessed

        guard let path = Bundle.main.path(forResource: "model_details", ofType: "json") else {
            print("❌ model_details.json not found in bundle")
            return false
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let models = json?["models"] as? [[String: Any]] else {
                print("❌ Invalid format in model details JSON")
                return false
            }

            // Find the model in our JSON data
            guard let modelData = models.first(where: { ($0["name"] as? String) == modelName }) else {
                print("❌ Model \(modelName) not found in local JSON data")
                return false
            }

            print("✅ Successfully found model \(modelName) in JSON:")
            if let displayName = modelData["displayName"] as? String {
                print("   Display Name: \(displayName)")
            }
            if let parameterSize = modelData["parameterSize"] as? String {
                print("   Parameter Size: \(parameterSize)")
            }

            return true
        } catch {
            print("❌ Error reading or parsing model details JSON: \(error)")
            return false
        }
    }
}