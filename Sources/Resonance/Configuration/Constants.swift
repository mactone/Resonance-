import Foundation

enum Constants {
    enum Audio {
        static let recordingFormat    = "m4a"
        static let sampleRate: Double = 44100
        static let channels: Int      = 1
    }

    enum AI {
        static let maxCategorizationTokens = 512
        static let maxArticleTokens        = 8192
        static let maxSummaryTokens        = 256
    }

    enum Aggregation {
        static let backgroundTaskIdentifier = "com.resonance.article-generation"
        static let minHoursBetweenAutoGen: Double = 24
    }

    enum Publishing {
        static let wordPressAPIPath    = "/wp-json/wp/v2/posts"
        static let mediumAPIBase       = "https://api.medium.com/v1"
        static let vocusAPIBase        = "https://vocus.cc/api"
    }

    enum UI {
        static let waveformBarCount    = 30
        static let defaultAccentHex    = "#6B9BFF"
    }
}
