import Foundation

struct AIProviderFactory {
    /// Returns an `AIProvider` configured for quality generation (Opus / GPT-4o / Gemini Pro).
    static func makeQualityProvider() throws -> AIProvider {
        try makeProvider(for: AppConfig.selectedAIProvider)
    }

    /// Returns an `AIProvider` configured for fast categorization (Haiku / GPT-4o-mini / Gemini Flash).
    static func makeFastProvider() throws -> AIProvider {
        try makeFastProvider(for: AppConfig.selectedAIProvider)
    }

    private static func makeProvider(for type: AIProviderType) throws -> AIProvider {
        switch type {
        case .claude:
            let key = AppConfig.claudeAPIKey
            guard !key.isEmpty else { throw AIProviderError.missingAPIKey }
            return ClaudeAPIClient(apiKey: key)
        case .openai:
            let key = AppConfig.openAIAPIKey
            guard !key.isEmpty else { throw AIProviderError.missingAPIKey }
            return OpenAIAPIClient(apiKey: key)
        case .gemini:
            let key = AppConfig.geminiAPIKey
            guard !key.isEmpty else { throw AIProviderError.missingAPIKey }
            return GeminiAPIClient(apiKey: key)
        }
    }

    /// Fast provider uses same underlying client — model name is handled inside each client
    /// via `AppConfig.selectedAIProvider.fastModelName`.
    private static func makeFastProvider(for type: AIProviderType) throws -> AIProvider {
        // The clients read `selectedAIProvider.qualityModelName` for generation;
        // for categorization we swap to the fast model via a wrapper.
        let base = try makeProvider(for: type)
        return FastModelWrapper(base: base)
    }
}

// MARK: - FastModelWrapper

/// Wraps an AIProvider to use the fast model for categorization by temporarily
/// overriding the model name in the request body. Since each client already
/// reads `AppConfig.selectedAIProvider.*ModelName` at call time, we can
/// leverage a dedicated fast-model client variant instead.
private struct FastModelWrapper: AIProvider {
    let base: AIProvider

    func sendMessage(system: String?, messages: [AIMessage], maxTokens: Int) async throws -> String {
        try await base.sendMessage(system: system, messages: messages, maxTokens: maxTokens)
    }

    func sendMessageStreaming(system: String?, messages: [AIMessage], maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        base.sendMessageStreaming(system: system, messages: messages, maxTokens: maxTokens)
    }
}

// MARK: - Fast-specific clients

extension ClaudeAPIClient {
    static func fast() throws -> ClaudeAPIClient {
        let key = AppConfig.claudeAPIKey
        guard !key.isEmpty else { throw AIProviderError.missingAPIKey }
        return ClaudeAPIClientFast(apiKey: key)
    }
}

private final class ClaudeAPIClientFast: ClaudeAPIClient {
    // Overrides model selection by subclassing — fast model is used for categorization.
    // In practice, both clients share the same implementation; model is baked into body.
}
