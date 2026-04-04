import Foundation

struct BlogPublisherFactory {
    static func publisher(for config: BlogPlatformConfig) -> BlogPublisher {
        switch config.platformType {
        case .wordpress: return WordPressPublisher()
        case .substack:  return SubstackPublisher()
        case .vocus:     return VocusPublisher()
        }
    }

    static func publisher(for platform: BlogPlatform) -> BlogPublisher {
        switch platform {
        case .wordpress: return WordPressPublisher()
        case .substack:  return SubstackPublisher()
        case .vocus:     return VocusPublisher()
        }
    }
}
