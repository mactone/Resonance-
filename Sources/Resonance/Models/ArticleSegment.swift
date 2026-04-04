import SwiftData
import Foundation

/// One paragraph/chunk of an article. Enables paragraph-level TTS pause/resume.
@Model
final class ArticleSegment {
    var id: UUID
    var index: Int
    var text: String
    var isSpoken: Bool

    @Relationship(deleteRule: .nullify)
    var article: Article?

    init(index: Int, text: String) {
        self.id = UUID()
        self.index = index
        self.text = text
        self.isSpoken = false
    }

    var wordCount: Int {
        text.split(separator: " ").count
    }
}
