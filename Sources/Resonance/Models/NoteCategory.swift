import SwiftData
import Foundation

/// Named `NoteCategory` to avoid conflict with SwiftUI's `Category` / Foundation's own `Category`.
@Model
final class NoteCategory {
    var id: UUID
    var name: String
    var colorHex: String        // "#FF6B6B"
    var systemIconName: String  // SF Symbol name
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \VoiceNote.category)
    var notes: [VoiceNote]

    @Relationship(deleteRule: .nullify, inverse: \Article.category)
    var articles: [Article]

    init(name: String, colorHex: String = "#6B9BFF", systemIconName: String = "folder.fill") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.systemIconName = systemIconName
        self.createdAt = .now
        self.notes = []
        self.articles = []
    }

    /// Unprocessed notes that haven't been included in any article yet.
    var unprocessedNotes: [VoiceNote] {
        notes.filter { !$0.isProcessed }
    }
}
