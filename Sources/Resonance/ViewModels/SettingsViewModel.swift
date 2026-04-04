import AVFoundation
import SwiftData
import Observation
import Foundation

@Observable
final class SettingsViewModel {
    // AI
    var selectedProvider: AIProviderType = AppConfig.selectedAIProvider
    var claudeKey: String = AppConfig.claudeAPIKey
    var openAIKey: String = AppConfig.openAIAPIKey
    var geminiKey: String = AppConfig.geminiAPIKey

    // Transcription
    var transcriptionBackend: TranscriptionBackend = AppConfig.transcriptionBackend

    // TTS
    var ttsRate: Float = AppConfig.ttsRate
    var selectedVoiceIdentifier: String = AppConfig.ttsVoiceIdentifier
    var availableVoices: [AVSpeechSynthesisVoice] = []

    // Auto-aggregation
    var autoAggregationEnabled: Bool = AppConfig.autoAggregationEnabled
    var autoAggregationMinNotes: Int = AppConfig.autoAggregationMinNotes

    // Blog platforms
    var blogPlatforms: [BlogPlatformConfig] = []
    var validationStatus: [UUID: Bool] = [:]

    // State
    var isSaving: Bool = false
    var saveMessage: String?

    private var modelContext: ModelContext?

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadBlogPlatforms()
        loadVoices()
    }

    func save() {
        AppConfig.selectedAIProvider = selectedProvider
        AppConfig.claudeAPIKey = claudeKey
        AppConfig.openAIAPIKey = openAIKey
        AppConfig.geminiAPIKey = geminiKey
        AppConfig.transcriptionBackend = transcriptionBackend
        AppConfig.ttsRate = ttsRate
        AppConfig.ttsVoiceIdentifier = selectedVoiceIdentifier
        AppConfig.autoAggregationEnabled = autoAggregationEnabled
        AppConfig.autoAggregationMinNotes = autoAggregationMinNotes
        saveMessage = "設定已儲存"
    }

    // MARK: - Voices

    private func loadVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("zh") || $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Blog Platforms

    func loadBlogPlatforms() {
        guard let ctx = modelContext else { return }
        blogPlatforms = (try? ctx.fetch(FetchDescriptor<BlogPlatformConfig>(
            sortBy: [SortDescriptor(\.createdAt)]
        ))) ?? []
    }

    func addPlatform(type: BlogPlatform, displayName: String, blogURL: String, username: String, apiKey: String) {
        guard let ctx = modelContext else { return }
        let config = BlogPlatformConfig(
            platformType: type,
            displayName: displayName,
            blogURL: blogURL,
            username: username
        )
        AppConfig.setBlogAPIKey(apiKey, for: config.keychainKey)
        ctx.insert(config)
        try? ctx.save()
        loadBlogPlatforms()
    }

    func deletePlatform(_ config: BlogPlatformConfig) {
        KeychainService.shared.delete(key: config.keychainKey)
        modelContext?.delete(config)
        try? modelContext?.save()
        loadBlogPlatforms()
    }

    func setDefaultPlatform(_ config: BlogPlatformConfig) {
        for p in blogPlatforms { p.isDefault = false }
        config.isDefault = true
        try? modelContext?.save()
    }

    func validatePlatform(_ config: BlogPlatformConfig) async {
        let publisher = BlogPublisherFactory.publisher(for: config)
        let valid = (try? await publisher.validateCredentials(config: config)) ?? false
        validationStatus[config.id] = valid
    }
}
