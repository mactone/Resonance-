import Foundation

struct PublishResult {
    let url: URL
    let postId: String
    let publishedAt: Date
}

protocol BlogPublisher {
    var platformType: BlogPlatform { get }

    func publish(
        article: Article,
        config: BlogPlatformConfig,
        asDraft: Bool
    ) async throws -> PublishResult

    func validateCredentials(config: BlogPlatformConfig) async throws -> Bool
}

// MARK: - Common Error

enum PublishingError: LocalizedError {
    case missingCredentials
    case networkError(underlying: Error)
    case apiError(statusCode: Int, message: String)
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .missingCredentials:      return "Platform credentials are not configured."
        case .networkError(let e):     return "Network error: \(e.localizedDescription)"
        case .apiError(let c, let m):  return "Publishing failed (\(c)): \(m)"
        case .unsupportedPlatform:     return "This platform is not yet supported."
        }
    }
}
