import Foundation

struct AppConfig {
    private init() {}

    // MARK: - AI Provider

    static var selectedAIProvider: AIProviderType {
        get {
            let raw = UserDefaults.standard.string(forKey: "selectedAIProvider") ?? ""
            return AIProviderType(rawValue: raw) ?? .claude
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "selectedAIProvider") }
    }

    static var claudeAPIKey: String {
        get { KeychainService.shared.read(key: "resonance.ai.claude") ?? "" }
        set { KeychainService.shared.write(key: "resonance.ai.claude", value: newValue) }
    }

    static var openAIAPIKey: String {
        get { KeychainService.shared.read(key: "resonance.ai.openai") ?? "" }
        set { KeychainService.shared.write(key: "resonance.ai.openai", value: newValue) }
    }

    static var geminiAPIKey: String {
        get { KeychainService.shared.read(key: "resonance.ai.gemini") ?? "" }
        set { KeychainService.shared.write(key: "resonance.ai.gemini", value: newValue) }
    }

    // MARK: - Transcription

    static var transcriptionBackend: TranscriptionBackend {
        get {
            let raw = UserDefaults.standard.string(forKey: "transcriptionBackend") ?? ""
            return TranscriptionBackend(rawValue: raw) ?? .appleSpeech
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "transcriptionBackend") }
    }

    // MARK: - TTS

    static var ttsVoiceIdentifier: String {
        get { UserDefaults.standard.string(forKey: "ttsVoiceIdentifier") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "ttsVoiceIdentifier") }
    }

    static var ttsRate: Float {
        get { UserDefaults.standard.float(forKey: "ttsRate").isZero ? 0.5 : UserDefaults.standard.float(forKey: "ttsRate") }
        set { UserDefaults.standard.set(newValue, forKey: "ttsRate") }
    }

    // MARK: - Auto-Aggregation

    static var autoAggregationEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "autoAggregationEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "autoAggregationEnabled") }
    }

    static var autoAggregationMinNotes: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "autoAggregationMinNotes")
            return v == 0 ? 3 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: "autoAggregationMinNotes") }
    }

    // MARK: - Helpers

    static func blogAPIKey(for keychainKey: String) -> String {
        KeychainService.shared.read(key: keychainKey) ?? ""
    }

    static func setBlogAPIKey(_ value: String, for keychainKey: String) {
        KeychainService.shared.write(key: keychainKey, value: value)
    }
}

// MARK: - Supporting Enums

enum AIProviderType: String, CaseIterable, Identifiable {
    case claude = "claude"
    case openai = "openai"
    case gemini = "gemini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openai: return "ChatGPT (OpenAI)"
        case .gemini: return "Gemini (Google)"
        }
    }

    var fastModelName: String {
        switch self {
        case .claude: return "claude-haiku-4-5"
        case .openai: return "gpt-4o-mini"
        case .gemini: return "gemini-2.0-flash"
        }
    }

    var qualityModelName: String {
        switch self {
        case .claude: return "claude-opus-4-5"
        case .openai: return "gpt-4o"
        case .gemini: return "gemini-1.5-pro"
        }
    }
}

enum TranscriptionBackend: String, CaseIterable, Identifiable {
    case appleSpeech = "appleSpeech"
    case whisper     = "whisper"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleSpeech: return "Apple Speech（離線、免費）"
        case .whisper:     return "Whisper API（OpenAI、更準確）"
        }
    }
}
