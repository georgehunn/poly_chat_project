//
//  open_chatTests.swift
//  open_chatTests
//
//  Created by George Hunn on 24.03.26.
//

import Testing
@testable import open_chat

struct open_chatTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func testModelDetailsFileExists() async throws {
        // Test that the model details JSON file exists in the bundle
        let path = Bundle.main.path(forResource: "model_details", ofType: "json")
        #expect(path != nil, "model_details.json should exist in the bundle")
    }

    @Test func testModelDetailsFileParses() async throws {
        // Test that the model details JSON file can be parsed
        guard let path = Bundle.main.path(forResource: "model_details", ofType: "json") else {
            Issue.record("model_details.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            #expect(json != nil, "JSON should parse successfully")

            if let json = json {
                let models = json["models"] as? [[String: Any]]
                #expect(models != nil, "models array should exist")
                #expect(models?.isEmpty == false, "models array should not be empty")
            }
        } catch {
            Issue.record("Error parsing JSON: \(error)")
        }
    }
}
