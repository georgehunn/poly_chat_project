import Foundation
import SwiftUI

class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()

    @AppStorage("analyticsEnabled") var isEnabled = true

    /// True if Supabase is configured with real credentials (not placeholder)
    var isConfigured: Bool {
        !AnalyticsConfig.supabaseURL.contains("YOUR_PROJECT") &&
        !AnalyticsConfig.supabaseAnonKey.contains("YOUR_ANON_KEY")
    }

    private let secureStorage = SecureStorageService()
    private var _deviceId: UUID?
    private var errorBuffer: [ErrorEventPayload] = []
    private var messageBuffer: [MessageEventPayload] = []
    private var flushTimer: Timer?
    private var deviceRegistered = false

    private let errorBufferKey = "analyticsErrorBuffer"
    private let messageBufferKey = "analyticsMessageBuffer"

    private init() {
        restoreBuffers()
        startFlushTimer()
    }

    // MARK: - Device ID

    var deviceId: UUID {
        if let cached = _deviceId { return cached }
        if let stored = secureStorage.getDeviceId() {
            _deviceId = stored
            return stored
        }
        let newId = UUID()
        _ = secureStorage.saveDeviceId(newId)
        _deviceId = newId
        return newId
    }

    // MARK: - Tracking

    func trackMessage(role: String, conversation: Conversation, toolName: String? = nil, attachmentType: String? = nil) {
        guard isEnabled, isConfigured else { return }

        // 1. Buffer the individual message event
        let payload = MessageEventPayload(
            deviceId: deviceId,
            conversationId: conversation.id,
            modelName: conversation.model.name,
            providerName: conversation.model.provider,
            messageRole: role,
            toolName: toolName,
            attachmentType: attachmentType,
            timestamp: Date()
        )
        messageBuffer.append(payload)

        print("[Analytics] trackMessage — role:\(role) tool:\(toolName ?? "none") buffer:\(messageBuffer.count)")

        if errorBuffer.count + messageBuffer.count >= 10 {
            Task { await flush() }
        }
    }

    func trackError(type: String, domain: String, conversationId: UUID? = nil, model: String? = nil, provider: String? = nil) {
        guard isEnabled, isConfigured else { return }

        let payload = ErrorEventPayload(
            deviceId: deviceId,
            errorType: type,
            errorDomain: domain,
            occurredAt: Date(),
            conversationId: conversationId,
            modelName: model,
            providerName: provider
        )
        errorBuffer.append(payload)
    }

    // MARK: - Flush to Supabase

    func flush() async {
        guard isEnabled, isConfigured else {
            print("[Analytics] flush skipped — enabled:\(isEnabled) configured:\(isConfigured)")
            return
        }
        guard !errorBuffer.isEmpty || !messageBuffer.isEmpty else {
            print("[Analytics] flush skipped — buffers empty")
            return
        }

        print("[Analytics] flush starting — errors:\(errorBuffer.count) messages:\(messageBuffer.count) deviceRegistered:\(deviceRegistered)")

        // Register device if not done yet
        if !deviceRegistered {
            await registerDevice()
            guard deviceRegistered else {
                print("[Analytics] flush aborted — device registration failed")
                return
            }
        }

        let errors = Array(errorBuffer)

        // Flush errors (insert)
        if !errors.isEmpty {
            let success = await postToSupabase(
                table: "error_events",
                payload: errors,
                upsert: false
            )
            if success {
                errorBuffer.removeAll()
            }
        }

        // Flush message events (insert)
        let messages = Array(messageBuffer)
        if !messages.isEmpty {
            let success = await postToSupabase(
                table: "message_events",
                payload: messages,
                upsert: false
            )
            if success {
                messageBuffer.removeAll()
            }
        }

        persistBuffers()
    }

    // MARK: - Fetch Dashboard Data

    func fetchDailyStats() async -> [DailyStat] {
        print("[Analytics] fetchDailyStats called")
        guard let url = URL(string: "\(AnalyticsConfig.supabaseURL)/rest/v1/daily_stats?order=stat_date.desc&limit=500") else {
            print("[Analytics] fetchDailyStats — invalid URL")
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(AnalyticsConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AnalyticsConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[Analytics] Failed to fetch daily_stats: HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return []
            }
            let decoder = JSONDecoder()
            let stats = try decoder.decode([DailyStat].self, from: data)
            print("[Analytics] fetchDailyStats — got \(stats.count) rows")
            return stats
        } catch {
            print("[Analytics] Error fetching daily_stats: \(error)")
            return []
        }
    }

    // MARK: - Crash Report Check

    func checkForPendingCrashReport() {
        guard isEnabled else { return }
        guard let crashInfo = CrashReporter.readAndClearCrashMarker() else { return }

        let payload = ErrorEventPayload(
            deviceId: deviceId,
            errorType: crashInfo.signal,
            errorDomain: "crash",
            occurredAt: crashInfo.timestamp,
            conversationId: nil,
            modelName: nil,
            providerName: nil
        )
        errorBuffer.append(payload)
        Task { await flush() }
    }

    // MARK: - Lifecycle

    func onBackground() {
        persistBuffers()
        Task { await flush() }
    }

    func startFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.flush() }
        }
    }

    // MARK: - Private Helpers

    private func registerDevice() async {
        let registration = DeviceRegistration(
            deviceId: deviceId,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            osVersion: UIDevice.current.systemVersion
        )

        // Use ignoreDuplicates instead of upsert — device only needs to be inserted once,
        // and this avoids requiring UPDATE permission on the devices table.
        let success = await postToSupabase(
            table: "devices",
            payload: [registration],
            upsert: false,
            ignoreDuplicates: true
        )
        if success {
            deviceRegistered = true
        }
    }

    private func postToSupabase<T: Encodable>(table: String, payload: [T], upsert: Bool, onConflict: String? = nil, ignoreDuplicates: Bool = false) async -> Bool {
        guard var urlComponents = URLComponents(string: "\(AnalyticsConfig.supabaseURL)/rest/v1/\(table)") else {
            return false
        }

        if (upsert || ignoreDuplicates), let onConflict {
            urlComponents.queryItems = [URLQueryItem(name: "on_conflict", value: onConflict)]
        }

        guard let url = urlComponents.url else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(AnalyticsConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AnalyticsConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if upsert {
            request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        } else if ignoreDuplicates {
            request.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            request.httpBody = try encoder.encode(payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            let success = (200...299).contains(httpResponse.statusCode)
            if !success {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("[Analytics] POST /\(table) failed: HTTP \(httpResponse.statusCode)")
                print("[Analytics] Response: \(body)")
                print("[Analytics] URL: \(url.absoluteString)")
            } else {
                print("[Analytics] POST /\(table) succeeded: HTTP \(httpResponse.statusCode)")
            }
            return success
        } catch {
            print("[Analytics] POST /\(table) error: \(error)")
            return false
        }
    }

    // MARK: - Buffer Persistence

    private func persistBuffers() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(errorBuffer) {
            UserDefaults.standard.set(data, forKey: errorBufferKey)
        }
        if let data = try? encoder.encode(messageBuffer) {
            UserDefaults.standard.set(data, forKey: messageBufferKey)
        }
    }

    private func restoreBuffers() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = UserDefaults.standard.data(forKey: errorBufferKey),
           let errors = try? decoder.decode([ErrorEventPayload].self, from: data) {
            errorBuffer = errors
        }
        if let data = UserDefaults.standard.data(forKey: messageBufferKey),
           let messages = try? decoder.decode([MessageEventPayload].self, from: data) {
            messageBuffer = messages
        }
    }
}
