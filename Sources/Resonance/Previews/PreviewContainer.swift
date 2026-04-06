import SwiftData
import Foundation

// MARK: - Preview Container

@MainActor
struct PreviewContainer {
    static let container: ModelContainer = {
        let schema = Schema([VoiceNote.self, NoteCategory.self, Article.self, ArticleSegment.self, BlogPlatformConfig.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    /// Seeds sample data and returns the context.
    static func makeContext() -> ModelContext {
        let ctx = container.mainContext

        // Categories
        let tech   = NoteCategory(name: "科技",   colorHex: "#6B9BFF", systemIconName: "cpu.fill")
        let health = NoteCategory(name: "健康",   colorHex: "#4CAF50", systemIconName: "figure.run")
        let create = NoteCategory(name: "創作",   colorHex: "#FF9800", systemIconName: "lightbulb.fill")
        [tech, health, create].forEach { ctx.insert($0) }

        // Voice notes
        let note1 = VoiceNote(rawTranscription: "今天在三峽河堤跑步時，突然想到創作和運動節奏的關係，有節奏的運動似乎會讓大腦進入更好的創意狀態。", recordedAt: .now.addingTimeInterval(-3600), durationSeconds: 45)
        note1.cleanedTranscription = note1.rawTranscription
        note1.category = create
        note1.isTranscribed = true
        note1.isCategorized = true
        note1.isProcessed = true

        let note2 = VoiceNote(rawTranscription: "剛剛看到一篇研究說有氧運動可以提升 alpha 腦波活動，這和創意思考高度相關，值得深入研究。", recordedAt: .now.addingTimeInterval(-7200), durationSeconds: 32)
        note2.cleanedTranscription = note2.rawTranscription
        note2.category = create
        note2.isTranscribed = true
        note2.isCategorized = true
        note2.isProcessed = true

        let note3 = VoiceNote(rawTranscription: "想到一個 App 概念：可以在跑步時用語音記錄想法，然後 AI 自動整理成文章。", recordedAt: .now.addingTimeInterval(-1800), durationSeconds: 28)
        note3.cleanedTranscription = note3.rawTranscription
        note3.category = tech
        note3.isTranscribed = true
        note3.isCategorized = true
        note3.isProcessed = false

        [note1, note2, note3].forEach { ctx.insert($0) }

        // Article with segments
        let article = Article(
            title: "運動節奏與創意思維的深度連結",
            body: """
            研究顯示，有節奏的有氧運動能顯著提升人的創意思考能力。當我們在三峽的河堤上跑步，感受著規律的步伐節奏，大腦的 alpha 腦波活動也隨之增強。

            這種狀態下，我們更容易產生靈感，更容易進入心流。許多創作者、作家、音樂家都有固定的運動習慣，這並非巧合。

            下次當你需要解決一個棘手的問題時，不妨先出去跑個步，讓節奏幫你打開思路。
            """
        )
        article.summary = "探討有規律的有氧運動如何透過增強 alpha 腦波活動來提升創意思考，以及如何將運動習慣融入創作流程。"
        article.category = create
        article.sourceNotes = [note1, note2]
        article.generationStatus = .ready
        article.lastPlayedAt = .now.addingTimeInterval(-600)
        article.playbackPositionSeconds = 1

        let paragraphs = article.body.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        for (i, para) in paragraphs.enumerated() {
            let seg = ArticleSegment(index: i, text: para.trimmingCharacters(in: .whitespacesAndNewlines))
            seg.article = article
            ctx.insert(seg)
        }
        ctx.insert(article)

        // Second shorter article
        let article2 = Article(title: "三峽晨跑日記：身心觀察", body: "連續三週的晨跑讓我發現，運動不只是體力的鍛練，更是思維的清理。")
        article2.summary = "三週晨跑的身心觀察與感悟。"
        article2.category = health
        article2.generationStatus = .ready
        let seg2 = ArticleSegment(index: 0, text: article2.body)
        seg2.article = article2
        ctx.insert(seg2)
        ctx.insert(article2)

        try? ctx.save()
        return ctx
    }
}
