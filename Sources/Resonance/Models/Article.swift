import SwiftData
import Foundation

@Model
final class Article {
    var id: UUID
    var title: String
    var body: String
    var summary: String
    var generatedAt: Date
    var lastPlayedAt: Date?
    var playbackPositionSeconds: Double
    var isFullyRead: Bool
    var generationStatusRaw: String     // GenerationStatus raw value
    var publishStatusRaw: String        // PublishStatus raw value
    var publishedURLString: String?
    var publishedAt: Date?

    @Relationship(deleteRule: .nullify)
    var category: NoteCategory?

    @Relationship(deleteRule: .nullify)
    var sourceNotes: [VoiceNote]

    @Relationship(deleteRule: .cascade, inverse: \ArticleSegment.article)
    var segments: [ArticleSegment]

    init(title: String = "", body: String = "", summary: String = "") {
        self.id = UUID()
        self.title = title
        self.body = body
        self.summary = summary
        self.generatedAt = .now
        self.playbackPositionSeconds = 0
        self.isFullyRead = false
        self.generationStatusRaw = GenerationStatus.pending.rawValue
        self.publishStatusRaw = PublishStatus.unpublished.rawValue
        self.sourceNotes = []
        self.segments = []
    }

    var generationStatus: GenerationStatus {
        get { GenerationStatus(rawValue: generationStatusRaw) ?? .pending }
        set { generationStatusRaw = newValue.rawValue }
    }

    var publishStatus: PublishStatus {
        get { PublishStatus(rawValue: publishStatusRaw) ?? .unpublished }
        set { publishStatusRaw = newValue.rawValue }
    }

    var publishedURL: URL? {
        get { publishedURLString.flatMap { URL(string: $0) } }
        set { publishedURLString = newValue?.absoluteString }
    }

    var sortedSegments: [ArticleSegment] {
        segments.sorted { $0.index < $1.index }
    }

    var estimatedReadingMinutes: Int {
        let words = body.split(separator: " ").count
        return max(1, words / 200)
    }
}

// MARK: - Status Enums

enum GenerationStatus: String, Codable {
    case pending, generating, ready, failed
}

enum PublishStatus: String, Codable {
    case unpublished, publishing, published, failed
}
