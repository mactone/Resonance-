import Foundation

enum ArticleChunk {
    case title(String)
    case bodyText(String)
    case done
}

final class ArticleGenerationService {
    private let provider: AIProvider

    init(provider: AIProvider) {
        self.provider = provider
    }

    // MARK: - Generate (streaming)

    func generateArticle(
        from notes: [VoiceNote],
        category: NoteCategory?,
        continuationContext: Article? = nil
    ) -> AsyncThrowingStream<ArticleChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let system = buildSystemPrompt(continuationContext: continuationContext)
                    let userContent = buildUserPrompt(notes: notes, category: category)

                    var titleEmitted = false
                    var buffer = ""

                    for try await chunk in provider.sendMessageStreaming(
                        system: system,
                        messages: [AIMessage(role: "user", content: userContent)],
                        maxTokens: Constants.AI.maxArticleTokens
                    ) {
                        buffer += chunk

                        // Extract title from first line if not yet emitted
                        if !titleEmitted, buffer.contains("\n") {
                            let lines = buffer.components(separatedBy: "\n")
                            if let firstLine = lines.first {
                                let title = firstLine
                                    .trimmingCharacters(in: .whitespaces)
                                    .replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                                continuation.yield(.title(title))
                                titleEmitted = true
                                buffer = lines.dropFirst().joined(separator: "\n")
                            }
                        } else if titleEmitted {
                            continuation.yield(.bodyText(chunk))
                            buffer = ""
                        }
                    }

                    // Flush remaining buffer
                    if !buffer.isEmpty && titleEmitted {
                        continuation.yield(.bodyText(buffer))
                    }

                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Summary

    func generateSummary(for articleText: String) async throws -> String {
        let prompt = "Summarise the following article in 2 sentences (respond in the same language as the article):\n\n\(articleText.prefix(3000))"
        return try await provider.sendMessage(
            system: nil,
            messages: [AIMessage(role: "user", content: prompt)],
            maxTokens: Constants.AI.maxSummaryTokens
        )
    }

    // MARK: - Prompts

    private func buildSystemPrompt(continuationContext: Article?) -> String {
        var prompt = """
        You are a thoughtful writer who synthesises fleeting voice notes into a coherent, engaging article. \
        The article should flow naturally as if written by the speaker, preserving their voice and style. \
        Structure with clear paragraphs. Use markdown headers sparingly. \
        Target length: 400–800 words for 3–7 notes. \
        Start with a compelling title on the first line (no markdown prefix), then the article body.
        """

        if let ctx = continuationContext {
            prompt += "\n\nA previous article was generated on this topic. Continue naturally from where it left off.\nPrevious summary: \(ctx.summary)"
        }
        return prompt
    }

    private func buildUserPrompt(notes: [VoiceNote], category: NoteCategory?) -> String {
        var lines: [String] = []
        if let cat = category {
            lines.append("Topic: \(cat.name)\n")
        }
        lines.append("Voice notes to synthesise (chronological order):")
        for (i, note) in notes.enumerated() {
            let date = note.recordedAt.formatted(date: .abbreviated, time: .shortened)
            lines.append("\(i + 1). [\(date)] \(note.displayText)")
        }
        return lines.joined(separator: "\n")
    }
}
