import Foundation

final class ClaudeAPIClient: AIProvider {
    private let apiKey: String
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - One-shot

    func sendMessage(system: String?, messages: [AIMessage], maxTokens: Int) async throws -> String {
        let body = buildBody(system: system, messages: messages, maxTokens: maxTokens, stream: false)
        let request = try buildRequest(body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        struct Response: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.content.first(where: { $0.type == "text" })?.text ?? ""
    }

    // MARK: - Streaming

    func sendMessageStreaming(system: String?, messages: [AIMessage], maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = buildBody(system: system, messages: messages, maxTokens: maxTokens, stream: true)
                    var request = try buildRequest(body: body)
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw AIProviderError.networkError(underlying: URLError(.badServerResponse))
                    }
                    guard http.statusCode == 200 else {
                        throw AIProviderError.apiError(statusCode: http.statusCode, message: "Streaming failed")
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: "),
                              let data = line.dropFirst(6).data(using: .utf8)
                        else { continue }

                        struct StreamEvent: Decodable {
                            let type: String
                            struct Delta: Decodable { let type: String; let text: String? }
                            let delta: Delta?
                        }
                        guard let event = try? JSONDecoder().decode(StreamEvent.self, from: data),
                              event.type == "content_block_delta",
                              let text = event.delta?.text
                        else { continue }

                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Helpers

    private func buildBody(system: String?, messages: [AIMessage], maxTokens: Int, stream: Bool) -> [String: Any] {
        var body: [String: Any] = [
            "model":      AppConfig.selectedAIProvider.qualityModelName,
            "max_tokens": maxTokens,
            "messages":   messages.map { ["role": $0.role, "content": $0.content] },
            "stream":     stream
        ]
        if let system { body["system"] = system }
        return body
    }

    private func buildRequest(body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey,        forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",  forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard http.statusCode == 200 else {
            struct ErrBody: Decodable { struct Err: Decodable { let message: String }; let error: Err }
            let msg = (try? JSONDecoder().decode(ErrBody.self, from: data))?.error.message ?? "Unknown error"
            if http.statusCode == 429 { throw AIProviderError.rateLimited(retryAfter: nil) }
            throw AIProviderError.apiError(statusCode: http.statusCode, message: msg)
        }
    }
}
