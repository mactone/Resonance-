import SwiftData
import Foundation

@Model
final class BlogPlatformConfig {
    var id: UUID
    var platformTypeRaw: String     // BlogPlatform raw value
    var displayName: String         // "My WordPress Blog"
    var blogURL: String             // base URL or identifier
    var username: String
    var keychainKey: String         // key used to retrieve credential from Keychain
    var isDefault: Bool
    var createdAt: Date

    init(
        platformType: BlogPlatform,
        displayName: String,
        blogURL: String,
        username: String
    ) {
        self.id = UUID()
        self.platformTypeRaw = platformType.rawValue
        self.displayName = displayName
        self.blogURL = blogURL
        self.username = username
        self.keychainKey = "resonance.blog.\(UUID().uuidString)"
        self.isDefault = false
        self.createdAt = .now
    }

    var platformType: BlogPlatform {
        get { BlogPlatform(rawValue: platformTypeRaw) ?? .wordpress }
        set { platformTypeRaw = newValue.rawValue }
    }
}

// MARK: - Platform Enum

enum BlogPlatform: String, CaseIterable, Identifiable {
    case wordpress = "wordpress"
    case substack  = "substack"
    case vocus     = "vocus"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wordpress: return "WordPress"
        case .substack:  return "Substack"
        case .vocus:     return "方格子 vocus.cc"
        }
    }

    var iconName: String {
        switch self {
        case .wordpress: return "globe"
        case .substack:  return "envelope.fill"
        case .vocus:     return "square.grid.2x2.fill"
        }
    }
}
