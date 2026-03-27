import Foundation

class NameGenerationService {
    static let shared = NameGenerationService()

    private init() {}

    // Popular boy names
    private let boyNames = [
        "Alexander", "Benjamin", "Christopher", "Daniel", "Ethan",
        "Gabriel", "Henry", "Isaac", "Jacob", "Kevin",
        "Liam", "Matthew", "Nathan", "Oliver", "Patrick",
        "Quentin", "Ryan", "Samuel", "Thomas", "William",
        "Adam", "Brian", "Charles", "David", "Edward",
        "Frank", "George", "Harry", "Ian", "Jack",
        "Kyle", "Lucas", "Michael", "Noah", "Oscar",
        "Peter", "Quinn", "Robert", "Stephen", "Tyler",
        "Uriah", "Victor", "Wyatt", "Xavier", "Yannick",
        "Zachary", "Andrew", "Barry", "Carl", "Derek"
    ]

    // Popular girl names
    private let girlNames = [
        "Abigail", "Charlotte", "Diana", "Elizabeth", "Fiona",
        "Grace", "Hannah", "Isabella", "Julia", "Katherine",
        "Lily", "Mia", "Nora", "Olivia", "Penelope",
        "Quinn", "Rachel", "Sophia", "Taylor", "Victoria",
        "Alice", "Bella", "Chloe", "Daisy", "Ella",
        "Faith", "Gemma", "Hope", "Ivy", "Jasmine",
        "Kayla", "Leah", "Maya", "Nina", "Opal",
        "Piper", "Rose", "Sadie", "Tessa", "Una",
        "Vera", "Willow", "Xena", "Yara", "Zoe",
        "Amelia", "Brianna", "Clara", "Delilah", "Elena"
    ]

    /// Generates a random name from combined boy and girl names
    /// - Returns: A randomly selected name from the combined lists
    func generateRandomName() -> String {
        // Combine both lists
        let allNames = boyNames + girlNames

        // Select a random name
        let randomIndex = Int.random(in: 0..<allNames.count)
        return allNames[randomIndex]
    }
}