import BackgroundTasks
import SwiftData
import Foundation

final class BackgroundGenerationService {
    static let shared = BackgroundGenerationService()
    private init() {}

    private let taskIdentifier = Constants.Aggregation.backgroundTaskIdentifier

    // MARK: - Registration (call before app finishes launching)

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleTask(task as! BGProcessingTask)
        }
    }

    // MARK: - Scheduling (call when app enters background)

    func scheduleBackgroundGeneration() {
        guard AppConfig.autoAggregationEnabled else { return }

        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)

        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Task Handler

    private func handleTask(_ task: BGProcessingTask) {
        task.expirationHandler = { task.setTaskCompleted(success: false) }

        Task {
            do {
                let container = try ModelContainer(for: VoiceNote.self, NoteCategory.self, Article.self, ArticleSegment.self)
                let context = ModelContext(container)
                let generated = try await generatePendingArticles(context: context)
                task.setTaskCompleted(success: true)

                if generated > 0 {
                    await sendLocalNotification(count: generated)
                }
            } catch {
                task.setTaskCompleted(success: false)
            }

            // Reschedule for next cycle
            scheduleBackgroundGeneration()
        }
    }

    // MARK: - Generation Logic

    @discardableResult
    func generatePendingArticles(context: ModelContext) async throws -> Int {
        let minNotes = AppConfig.autoAggregationMinNotes

        // Fetch all unprocessed notes grouped by category
        let descriptor = FetchDescriptor<VoiceNote>(
            predicate: #Predicate { !$0.isProcessed }
        )
        let allNotes = try context.fetch(descriptor)

        // Group by category
        var byCategory: [UUID?: [VoiceNote]] = [:]
        for note in allNotes {
            let key = note.category?.id
            byCategory[key, default: []].append(note)
        }

        var count = 0
        let provider = try AIProviderFactory.makeQualityProvider()
        let genService = ArticleGenerationService(provider: provider)

        for (_, notes) in byCategory where notes.count >= minNotes {
            // Sort by date
            let sorted = notes.sorted { $0.recordedAt < $1.recordedAt }
            let category = sorted.first?.category

            // Check hours since last generation in this category
            if let cat = category {
                let artDesc = FetchDescriptor<Article>(
                    predicate: #Predicate { $0.category?.id == cat.id },
                    sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
                )
                if let lastArticle = try context.fetch(artDesc).first {
                    let hoursSince = Date().timeIntervalSince(lastArticle.generatedAt) / 3600
                    guard hoursSince >= Constants.Aggregation.minHoursBetweenAutoGen else { continue }
                }
            }

            let article = Article()
            article.category = category
            article.sourceNotes = sorted
            article.generationStatus = .generating
            context.insert(article)

            var fullBody = ""
            var title = ""
            var segments: [ArticleSegment] = []
            var segIndex = 0
            var currentParagraph = ""

            for try await chunk in genService.generateArticle(from: sorted, category: category) {
                switch chunk {
                case .title(let t):
                    title = t
                case .bodyText(let text):
                    fullBody += text
                    currentParagraph += text
                    // Split into segments at double newlines
                    while let range = currentParagraph.range(of: "\n\n") {
                        let para = String(currentParagraph[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !para.isEmpty {
                            let seg = ArticleSegment(index: segIndex, text: para)
                            segments.append(seg)
                            segIndex += 1
                        }
                        currentParagraph = String(currentParagraph[range.upperBound...])
                    }
                case .done:
                    break
                }
            }

            // Flush remaining paragraph
            let remaining = currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty {
                segments.append(ArticleSegment(index: segIndex, text: remaining))
            }

            article.title = title
            article.body = fullBody
            article.segments = segments
            article.generationStatus = .ready
            article.summary = try await ArticleGenerationService(provider: provider).generateSummary(for: fullBody)

            // Mark notes as processed
            for note in sorted { note.isProcessed = true }

            try context.save()
            count += 1
        }

        return count
    }

    // MARK: - Notification

    private func sendLocalNotification(count: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Resonance"
        content.body = count == 1
            ? "新文章已生成，準備聆聽！"
            : "\(count) 篇新文章已生成，準備聆聽！"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
