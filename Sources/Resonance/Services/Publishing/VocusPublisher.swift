import Foundation

/// Publisher for 方格子 vocus.cc using their private REST API.
/// `blogURL` stores the publication slug (e.g. "mypublication").
/// `keychainKey` stores the Bearer token.
final class VocusPublisher: BlogPublisher {
    let platformType: BlogPlatform = .vocus

    private let baseURL = Constants.Publishing.vocusAPIBase

    func publish(article: Article, config: BlogPlatformConfig, asDraft: Bool) async throws -> PublishResult {
        let token = AppConfig.blogAPIKey(for: config.keychainKey)
        guard !token.isEmpty else {
            throw PublishingError.missingCredentials
        }

        guard let url = URL(string: "\(baseURL)/articles") else {
            throw PublishingError.apiError(statusCode: 0, message: "Invalid vocus API URL")
        }

        // vocus.cc API body (based on available public API documentation)
        let body: [String: Any] = [
            "title":   article.title,
            "content": article.body,
            "draft":   asDraft,
            "tags":    article.category.map { [$0.name] } ?? []
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PublishingError.networkError(underlying: URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw PublishingError.apiError(statusCode: http.statusCode, message: "vocus.cc rejected the post")
        }

        struct VocusResponse: Decodable {
            let id: String?
            let url: String?
            let slug: String?
        }
        let decoded = try JSONDecoder().decode(VocusResponse.self, from: data)
        let postURLString = decoded.url ?? "https://vocus.cc/@\(config.blogURL)/\(decoded.id ?? "")"
        guard let postURL = URL(string: postURLString) else {
            throw PublishingError.apiError(statusCode: 0, message: "Invalid response URL")
        }
        return PublishResult(url: postURL, postId: decoded.id ?? UUID().uuidString, publishedAt: .now)
    }

    func validateCredentials(config: BlogPlatformConfig) async throws -> Bool {
        let token = AppConfig.blogAPIKey(for: config.keychainKey)
        guard !token.isEmpty else { return false }

        guard let url = URL(string: "\(baseURL)/me") else { return false }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
}
