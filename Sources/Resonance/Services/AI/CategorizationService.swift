import Foundation

struct CategorizationResult {
    let categoryName: String
    let categoryIcon: String    // SF Symbol name
    let colorHex: String
    let cleanedText: String
    let confidence: Double
}

final class CategorizationService {
    private let provider: AIProvider

    init(provider: AIProvider) {
        self.provider = provider
    }

    func categorize(
        transcription: String,
        existingCategories: [NoteCategory]
    ) async throws -> CategorizationResult {
        let categoryList = existingCategories.map { $0.name }.joined(separator: ", ")

        let system = """
        You are an intelligent voice-note categorizer. Given a voice transcription (may be in Chinese or English), return a single JSON object with no other text.

        Fields:
        - category: string (category name; reuse existing if appropriate)
        - icon: string (SF Symbol name, e.g. "lightbulb.fill", "heart.fill", "brain.head.profile")
        - color: string (hex color, e.g. "#FF6B6B")
        - cleaned_text: string (remove filler words, fix grammar, keep meaning)
        - confidence: number (0.0–1.0)

        Existing categories: [\(categoryList.isEmpty ? "none" : categoryList)]
        Respond ONLY with valid JSON.
        """

        let response = try await provider.sendMessage(
            system: system,
            messages: [AIMessage(role: "user", content: transcription)],
            maxTokens: Constants.AI.maxCategorizationTokens
        )

        return try parseCategorizationJSON(response)
    }

    private func parseCategorizationJSON(_ json: String) throws -> CategorizationResult {
        // Strip markdown code blocks if present
        var clean = json.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```") {
            clean = clean
                .components(separatedBy: "\n")
                .dropFirst().dropLast()
                .joined(separator: "\n")
        }

        guard let data = clean.data(using: .utf8) else {
            throw AIProviderError.decodingError(description: "Invalid UTF-8")
        }

        struct Raw: Decodable {
            let category: String
            let icon: String
            let color: String
            let cleaned_text: String
            let confidence: Double
        }
        let raw = try JSONDecoder().decode(Raw.self, from: data)
        return CategorizationResult(
            categoryName: raw.category,
            categoryIcon: raw.icon,
            colorHex:     raw.color,
            cleanedText:  raw.cleaned_text,
            confidence:   raw.confidence
        )
    }
}
