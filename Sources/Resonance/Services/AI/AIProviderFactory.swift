import Foundation

struct AIProviderFactory {
    /// Returns an `AIProvider` using the quality model tier (for article generation).
    static func makeQualityProvider() throws -> AIProvider {
        try makeProvider(for: AppConfig.selectedAIProvider, useFastModel: false)
    }

    /// Returns an `AIProvider` using the fast model tier (for categorization).
    static func makeFastProvider() throws -> AIProvider {
        try makeProvider(for: AppConfig.selectedAIProvider, useFastModel: true)
    }

    private static func makeProvider(for type: AIProviderType, useFastModel: Bool) throws -> AIProvider {
        switch type {
        case .claude:
            let key = AppConfig.claudeAPIKey
            guard !key.isEmpty else { throw AIProviderError.missingAPIKey }
            return ClaudeAPIClient(apiKey: key, useFastModel: useFastModel)
        case .openai:
            let key = AppConfig.openAIAPIKey
            guard !key.isEmpty else { throw AIProviderError.missingAPIKey }
            return OpenAIAPIClient(apiKey: key, useFastModel: useFastModel)
        case .gemini:
            let key = AppConfig.geminiAPIKey
            guard !key.isEmpty else { throw AIProviderError.missingAPIKey }
            return GeminiAPIClient(apiKey: key, useFastModel: useFastModel)
        }
    }
}
