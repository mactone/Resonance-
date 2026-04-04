import SwiftData
import Observation
import Foundation

@Observable
final class HomeViewModel {
    var recentArticles: [Article] = []
    var unfinishedArticle: Article?     // most recently played but not finished
    var pendingNoteCount: Int = 0
    var isGenerating: Bool = false
    var errorMessage: String?

    private var modelContext: ModelContext?

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        guard let ctx = modelContext else { return }

        // Fetch 5 most recent ready articles
        var articleDesc = FetchDescriptor<Article>(
            predicate: #Predicate { $0.generationStatusRaw == "ready" },
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        articleDesc.fetchLimit = 5
        recentArticles = (try? ctx.fetch(articleDesc)) ?? []

        // Find unfinished article (last played, not fully read)
        var unfinishedDesc = FetchDescriptor<Article>(
            predicate: #Predicate { $0.lastPlayedAt != nil && !$0.isFullyRead && $0.generationStatusRaw == "ready" },
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        unfinishedDesc.fetchLimit = 1
        unfinishedArticle = (try? ctx.fetch(unfinishedDesc))?.first

        // Count unprocessed notes
        let noteDesc = FetchDescriptor<VoiceNote>(predicate: #Predicate { !$0.isProcessed })
        pendingNoteCount = (try? ctx.fetchCount(noteDesc)) ?? 0
    }

    // MARK: - Manual Trigger

    func generateArticlesNow() async {
        guard !isGenerating, let ctx = modelContext else { return }
        isGenerating = true
        errorMessage = nil
        do {
            let count = try await BackgroundGenerationService.shared.generatePendingArticles(context: ctx)
            if count == 0 { errorMessage = "Not enough notes yet (need \(AppConfig.autoAggregationMinNotes)+)." }
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }
}
