import SwiftData
import Foundation

@Model
final class VoiceNote {
    var id: UUID
    var audioFileName: String?          // relative filename stored; resolved via AudioFileManager
    var rawTranscription: String
    var cleanedTranscription: String
    var recordedAt: Date
    var durationSeconds: Double
    var isTranscribed: Bool
    var isCategorized: Bool
    var isProcessed: Bool               // included in at least one article

    @Relationship(deleteRule: .nullify)
    var category: NoteCategory?

    @Relationship(deleteRule: .nullify, inverse: \Article.sourceNotes)
    var articles: [Article]

    init(
        rawTranscription: String = "",
        recordedAt: Date = .now,
        durationSeconds: Double = 0
    ) {
        self.id = UUID()
        self.rawTranscription = rawTranscription
        self.cleanedTranscription = rawTranscription
        self.recordedAt = recordedAt
        self.durationSeconds = durationSeconds
        self.isTranscribed = false
        self.isCategorized = false
        self.isProcessed = false
        self.articles = []
    }

    var formattedDuration: String {
        let mins = Int(durationSeconds) / 60
        let secs = Int(durationSeconds) % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }

    var displayText: String {
        cleanedTranscription.isEmpty ? rawTranscription : cleanedTranscription
    }
}
