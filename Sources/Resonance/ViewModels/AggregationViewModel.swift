import SwiftData
import Observation
import Foundation

@Observable
final class AggregationViewModel {
    var availableNotes: [VoiceNote] = []
    var selectedNoteIDs: Set<UUID> = []
    var categories: [NoteCategory] = []
    var selectedCategory: NoteCategory?
    var generatedArticleTitle: String = ""
    var generatedArticleBody: String = ""
    var isGenerating: Bool = false
    var generationProgress: Double = 0
    var errorMessage: String?
    var generatedArticle: Article?

    private var modelContext: ModelContext?

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadNotes() {
        guard let ctx = modelContext else { return }
        let desc = FetchDescriptor<VoiceNote>(
            predicate: #Predicate { $0.isTranscribed },
            sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
        )
        availableNotes = (try? ctx.fetch(desc)) ?? []
        categories = (try? ctx.fetch(FetchDescriptor<NoteCategory>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    var selectedNotes: [VoiceNote] {
        availableNotes.filter { selectedNoteIDs.contains($0.id) }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    func toggleSelection(_ note: VoiceNote) {
        if selectedNoteIDs.contains(note.id) {
            selectedNoteIDs.remove(note.id)
        } else {
            selectedNoteIDs.insert(note.id)
        }
    }

    func selectAll() { selectedNoteIDs = Set(availableNotes.map { $0.id }) }
    func clearSelection() { selectedNoteIDs = [] }

    // MARK: - Generate

    func generateArticle() async {
        guard !selectedNotes.isEmpty, !isGenerating else { return }
        guard let ctx = modelContext else { return }

        isGenerating = true
        generatedArticleTitle = ""
        generatedArticleBody = ""
        errorMessage = nil
        generationProgress = 0

        do {
            let provider = try AIProviderFactory.makeQualityProvider()
            let service = ArticleGenerationService(provider: provider)

            var segTexts: [String] = []
            var currentParagraph = ""

            for try await chunk in service.generateArticle(from: selectedNotes, category: selectedCategory) {
                switch chunk {
                case .title(let t):
                    generatedArticleTitle = t
                case .bodyText(let text):
                    generatedArticleBody += text
                    currentParagraph += text
                    generationProgress = min(generationProgress + 0.02, 0.95)
                case .done:
                    generationProgress = 1.0
                }
            }

            // Build article segments from double-newline splits
            let paragraphs = generatedArticleBody
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let article = Article(title: generatedArticleTitle, body: generatedArticleBody)
            article.category = selectedCategory
            article.sourceNotes = selectedNotes
            article.generationStatus = .generating

            for (i, para) in paragraphs.enumerated() {
                let seg = ArticleSegment(index: i, text: para)
                article.segments.append(seg)
                ctx.insert(seg)
            }

            article.summary = try await service.generateSummary(for: generatedArticleBody)
            article.generationStatus = .ready
            ctx.insert(article)

            for note in selectedNotes { note.isProcessed = true }
            try ctx.save()

            generatedArticle = article
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    func regenerate() async {
        generatedArticle = nil
        await generateArticle()
    }
}
