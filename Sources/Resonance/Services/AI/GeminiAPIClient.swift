import Foundation

final class GeminiAPIClient: AIProvider {
    private let apiKey: String
    private let modelName: String
    private let baseURLString = "https://generativelanguage.googleapis.com/v1beta/models"

    init(apiKey: String, useFastModel: Bool = false) {
        self.apiKey = apiKey
        self.modelName = useFastModel
            ? AppConfig.selectedAIProvider.fastModelName
            : AppConfig.selectedAIProvider.qualityModelName
    }

    // MARK: - One-shot

    func sendMessage(system: String?, messages: [AIMessage], maxTokens: Int) async throws -> String {
        let model = modelName
        let url = URL(string: "\(baseURLString)/\(model):generateContent?key=\(apiKey)")!
        let body = buildBody(system: system, messages: messages, maxTokens: maxTokens)
        let request = try buildRequest(url: url, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        struct Response: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.candidates.first?.content.parts.first?.text ?? ""
    }

    // MARK: - Streaming

    func sendMessageStreaming(system: String?, messages: [AIMessage], maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let model = self.modelName
                    let url = URL(string: "\(self.baseURLString)/\(model):streamGenerateContent?key=\(self.apiKey)&alt=sse")!
                    let body = self.buildBody(system: system, messages: messages, maxTokens: maxTokens)
                    let request = try self.buildRequest(url: url, body: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        throw AIProviderError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Gemini streaming failed")
                    }

                    struct StreamChunk: Decodable {
                        struct Candidate: Decodable {
                            struct Content: Decodable {
                                struct Part: Decodable { let text: String? }
                                let parts: [Part]
                            }
                            let content: Content
                        }
                        let candidates: [Candidate]
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: "),
                              let data = line.dropFirst(6).data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                              let text = chunk.candidates.first?.content.parts.first?.text
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

    private func buildBody(system: String?, messages: [AIMessage], maxTokens: Int) -> [String: Any] {
        var contents: [[String: Any]] = messages.map { msg in
            ["role": msg.role == "assistant" ? "model" : "user",
             "parts": [["text": msg.content]]]
        }
        // Gemini uses systemInstruction at top-level
        var body: [String: Any] = [
            "contents":           contents,
            "generationConfig":   ["maxOutputTokens": maxTokens]
        ]
        if let system {
            body["systemInstruction"] = ["parts": [["text": system]]]
        }
        return body
    }

    private func buildRequest(url: URL, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard http.statusCode == 200 else {
            if http.statusCode == 429 { throw AIProviderError.rateLimited(retryAfter: nil) }
            throw AIProviderError.apiError(statusCode: http.statusCode, message: "Gemini error")
        }
    }
}
