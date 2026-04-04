import Foundation

// MARK: - Message

struct AIMessage {
    let role: String    // "user" or "assistant"
    let content: String
}

// MARK: - Protocol

protocol AIProvider {
    /// One-shot message call.
    func sendMessage(
        system: String?,
        messages: [AIMessage],
        maxTokens: Int
    ) async throws -> String

    /// Streaming message call — yields text deltas.
    func sendMessageStreaming(
        system: String?,
        messages: [AIMessage],
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error>
}

// MARK: - Errors

enum AIProviderError: LocalizedError {
    case missingAPIKey
    case rateLimited(retryAfter: TimeInterval?)
    case contextLengthExceeded
    case networkError(underlying: Error)
    case decodingError(description: String)
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:               return "API key is not configured."
        case .rateLimited(let t):          return "Rate limited. Retry after \(t.map { "\($0)s" } ?? "a moment")."
        case .contextLengthExceeded:       return "Input is too long for the AI model."
        case .networkError(let e):         return "Network error: \(e.localizedDescription)"
        case .decodingError(let d):        return "Failed to decode response: \(d)"
        case .apiError(let code, let msg): return "API error \(code): \(msg)"
        }
    }
}
