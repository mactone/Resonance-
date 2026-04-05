import Foundation

final class OpenAIAPIClient: AIProvider {
    private let apiKey: String
    private let modelName: String
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(apiKey: String, useFastModel: Bool = false) {
        self.apiKey = apiKey
        self.modelName = useFastModel
            ? AppConfig.selectedAIProvider.fastModelName
            : AppConfig.selectedAIProvider.qualityModelName
    }

    // MARK: - One-shot

    func sendMessage(system: String?, messages: [AIMessage], maxTokens: Int) async throws -> String {
        let body = buildBody(system: system, messages: messages, maxTokens: maxTokens, stream: false)
        let request = try buildRequest(body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        struct Response: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    // MARK: - Streaming

    func sendMessageStreaming(system: String?, messages: [AIMessage], maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = buildBody(system: system, messages: messages, maxTokens: maxTokens, stream: true)
                    let request = try buildRequest(body: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        throw AIProviderError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Streaming failed")
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8) else { continue }

                        struct StreamChunk: Decodable {
                            struct Choice: Decodable {
                                struct Delta: Decodable { let content: String? }
                                let delta: Delta
                            }
                            let choices: [Choice]
                        }
                        guard let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                              let text = chunk.choices.first?.delta.content
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
        var allMessages: [[String: String]] = []
        if let system {
            allMessages.append(["role": "system", "content": system])
        }
        allMessages += messages.map { ["role": $0.role, "content": $0.content] }

        return [
            "model":      modelName,
            "max_tokens": maxTokens,
            "messages":   allMessages,
            "stream":     stream
        ]
    }

    private func buildRequest(body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard http.statusCode == 200 else {
            if http.statusCode == 429 { throw AIProviderError.rateLimited(retryAfter: nil) }
            throw AIProviderError.apiError(statusCode: http.statusCode, message: "OpenAI error")
        }
    }
}
