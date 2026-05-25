import Foundation
import CoreML

final class LLMManager {
    static let shared = LLMManager()

    enum Provider: String, CaseIterable, Codable {
        case local = "Local"
        case openAI = "OpenAI"
    }

    enum ReplyIntent: String, CaseIterable, Identifiable, Codable {
        case general = "General"
        case scheduleMeeting = "Schedule meeting"
        case confirmAvailability = "Confirm availability"
        case followUp = "Follow up"
        case decline = "Decline gracefully"

        var id: String { rawValue }
    }

    struct Settings: Codable {
        var provider: Provider = .local
        var openAIModel: String = "gpt-4o-mini"
    }

    private let settingsKey = "LLMManagerSettings"
    private let openAIKeyService = "ASTAI.OpenAI"
    private let openAIAPIKeyAccount = "OpenAIAPIKey"
    private(set) var settings = Settings()
    private(set) var openAIAPIKey: String = ""

    private init() {
        loadSettings()
        loadOpenAIAPIKey()
    }

    func updateSettings(_ settings: Settings) {
        self.settings = settings
        saveSettings()
    }

    func updateOpenAIAPIKey(_ apiKey: String) {
        openAIAPIKey = apiKey
        saveOpenAIAPIKey()
    }

    func generateDraft(prompt: String) async -> String {
        switch settings.provider {
        case .openAI:
            if let response = await generateOpenAIResponse(prompt: prompt) {
                return response
            }
            fallthrough
        case .local:
            return generateLocalDraft(prompt: prompt)
        }
    }

    func generateReply(for message: String, intent: ReplyIntent) async -> String {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalPrompt = "Compose a reply using intent: \(intent.rawValue). Original message: \(normalized)"
        return await generateDraft(prompt: finalPrompt)
    }

    func detectIntent(from message: String) -> ReplyIntent {
        let lower = message.lowercased()
        if lower.contains("meeting") || lower.contains("schedule") || lower.contains("available") {
            return .scheduleMeeting
        }
        if lower.contains("confirm") || lower.contains("availability") || lower.contains("free") {
            return .confirmAvailability
        }
        if lower.contains("follow up") || lower.contains("checking in") || lower.contains("any update") {
            return .followUp
        }
        if lower.contains("can’t") || lower.contains("unable") || lower.contains("sorry") || lower.contains("not available") {
            return .decline
        }
        return .general
    }

    private func generateLocalDraft(prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("schedule meeting") || lower.contains("meeting") {
            return "Thanks for reaching out. I'm available next week for a meeting; please send a few time options and I'll confirm the best slot."
        }
        if lower.contains("confirm availability") || lower.contains("availability") {
            return "I appreciate your message. I can meet on the proposed date and will confirm the exact time shortly. Please let me know if your schedule changes."
        }
        if lower.contains("follow up") || lower.contains("checking in") {
            return "Thanks for checking in — I'm reviewing this now and will get back to you with a detailed update soon."
        }
        if lower.contains("decline") || lower.contains("unable") || lower.contains("not available") {
            return "Thank you for the invitation. Unfortunately I am unavailable at that time, but I can propose alternate dates if that helps."
        }
        return "Hi — thanks for your message. I'm available to meet; please propose a time and I'll confirm."
    }

    private func generateOpenAIResponse(prompt: String) async -> String? {
        guard !openAIAPIKey.isEmpty else {
            return nil
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": settings.openAIModel,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that writes professional email and message replies."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return nil
        }
        request.httpBody = data

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: responseData)
            return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let saved = try? JSONDecoder().decode(Settings.self, from: data) else {
            return
        }
        settings = saved
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    private func loadOpenAIAPIKey() {
        openAIAPIKey = KeychainHelper.read(service: openAIKeyService, account: openAIAPIKeyAccount) ?? ""
    }

    private func saveOpenAIAPIKey() {
        if openAIAPIKey.isEmpty {
            KeychainHelper.delete(service: openAIKeyService, account: openAIAPIKeyAccount)
        } else {
            KeychainHelper.save(openAIAPIKey, service: openAIKeyService, account: openAIAPIKeyAccount)
        }
    }

    func loadModel() throws -> MLModel {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: "AssistantLLM", withExtension: "mlmodelc") else {
            throw NSError(domain: "LLMManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model not found"])
        }
        return try MLModel(contentsOf: url)
    }
}

private struct OpenAIChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
