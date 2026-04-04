import SwiftData
import Observation
import Foundation

@Observable
final class LibraryViewModel {
    var articles: [Article] = []
    var notes: [VoiceNote] = []
    var categories: [NoteCategory] = []
    var selectedCategory: NoteCategory?
    var searchText: String = ""

    private var modelContext: ModelContext?

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        guard let ctx = modelContext else { return }

        // Articles
        var artDesc = FetchDescriptor<Article>(
            predicate: #Predicate { $0.generationStatusRaw == "ready" },
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        var allArticles = (try? ctx.fetch(artDesc)) ?? []
        if let cat = selectedCategory {
            allArticles = allArticles.filter { $0.category?.id == cat.id }
        }
        articles = allArticles

        // Notes
        var noteDesc = FetchDescriptor<VoiceNote>(
            sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
        )
        var allNotes = (try? ctx.fetch(noteDesc)) ?? []
        if let cat = selectedCategory {
            allNotes = allNotes.filter { $0.category?.id == cat.id }
        }
        if !searchText.isEmpty {
            allNotes = allNotes.filter {
                $0.displayText.localizedCaseInsensitiveContains(searchText)
            }
        }
        notes = allNotes

        // Categories
        categories = (try? ctx.fetch(FetchDescriptor<NoteCategory>(
            sortBy: [SortDescriptor(\.name)]
        ))) ?? []
    }

    func deleteNote(_ note: VoiceNote) {
        if let filename = note.audioFileName {
            AudioFileManager.shared.delete(filename: filename)
        }
        modelContext?.delete(note)
        try? modelContext?.save()
        refresh()
    }

    func deleteArticle(_ article: Article) {
        modelContext?.delete(article)
        try? modelContext?.save()
        refresh()
    }
}
