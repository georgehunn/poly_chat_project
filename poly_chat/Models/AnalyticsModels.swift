import Foundation

// MARK: - Supabase Insert Payloads

struct ErrorEventPayload: Codable {
    let deviceId: UUID
    let errorType: String
    let errorDomain: String
    let occurredAt: Date
    let conversationId: UUID?
    let modelName: String?
    let providerName: String?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case errorType = "error_type"
        case errorDomain = "error_domain"
        case occurredAt = "occurred_at"
        case conversationId = "conversation_id"
        case modelName = "model_name"
        case providerName = "provider_name"
    }
}

struct DeviceRegistration: Codable {
    let deviceId: UUID
    let appVersion: String?
    let osVersion: String?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case appVersion = "app_version"
        case osVersion = "os_version"
    }
}

struct MessageEventPayload: Codable {
    let deviceId: UUID
    let conversationId: UUID
    let modelName: String
    let providerName: String
    let messageRole: String
    let toolName: String?
    let attachmentType: String?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case conversationId = "conversation_id"
        case modelName = "model_name"
        case providerName = "provider_name"
        case messageRole = "message_role"
        case toolName = "tool_name"
        case attachmentType = "attachment_type"
        case timestamp
    }

    // Custom encode to always emit optionals as JSON null (not omitted).
    // PostgREST requires all objects in a batch POST to have identical keys.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(conversationId, forKey: .conversationId)
        try container.encode(modelName, forKey: .modelName)
        try container.encode(providerName, forKey: .providerName)
        try container.encode(messageRole, forKey: .messageRole)
        try container.encode(toolName, forKey: .toolName)
        try container.encode(attachmentType, forKey: .attachmentType)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

// MARK: - Supabase Read Models

struct DailyStat: Codable, Identifiable {
    var id: String { "\(statDate)-\(modelName)-\(providerName)" }

    let statDate: String
    let modelName: String
    let providerName: String
    let totalSessions: Int
    let totalMessages: Int
    let totalErrors: Int
    let uniqueDevices: Int

    enum CodingKeys: String, CodingKey {
        case statDate = "stat_date"
        case modelName = "model_name"
        case providerName = "provider_name"
        case totalSessions = "total_sessions"
        case totalMessages = "total_messages"
        case totalErrors = "total_errors"
        case uniqueDevices = "unique_devices"
    }

    var date: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: statDate)
    }
}
