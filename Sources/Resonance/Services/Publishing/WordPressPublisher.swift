import Foundation

final class WordPressPublisher: BlogPublisher {
    let platformType: BlogPlatform = .wordpress

    func publish(article: Article, config: BlogPlatformConfig, asDraft: Bool) async throws -> PublishResult {
        let apiKey = AppConfig.blogAPIKey(for: config.keychainKey)
        guard !config.blogURL.isEmpty, !config.username.isEmpty, !apiKey.isEmpty else {
            throw PublishingError.missingCredentials
        }

        let baseURL = config.blogURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)\(Constants.Publishing.wordPressAPIPath)") else {
            throw PublishingError.apiError(statusCode: 0, message: "Invalid blog URL")
        }

        let body: [String: Any] = [
            "title":   article.title,
            "content": article.body,
            "status":  asDraft ? "draft" : "publish"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // WordPress Application Password auth: username:app_password Base64
        let credentials = "\(config.username):\(apiKey)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PublishingError.networkError(underlying: URLError(.badServerResponse))
        }
        guard http.statusCode == 201 else {
            throw PublishingError.apiError(statusCode: http.statusCode, message: "WordPress rejected the post")
        }

        struct WPResponse: Decodable {
            let id: Int
            let link: String
            let date: String
        }
        let decoded = try JSONDecoder().decode(WPResponse.self, from: data)
        guard let postURL = URL(string: decoded.link) else {
            throw PublishingError.apiError(statusCode: 0, message: "Invalid response URL")
        }

        return PublishResult(url: postURL, postId: "\(decoded.id)", publishedAt: .now)
    }

    func validateCredentials(config: BlogPlatformConfig) async throws -> Bool {
        let apiKey = AppConfig.blogAPIKey(for: config.keychainKey)
        guard !config.blogURL.isEmpty, !config.username.isEmpty, !apiKey.isEmpty else { return false }

        let baseURL = config.blogURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/wp-json/wp/v2/users/me") else { return false }

        var request = URLRequest(url: url)
        let credentials = "\(config.username):\(apiKey)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
}
