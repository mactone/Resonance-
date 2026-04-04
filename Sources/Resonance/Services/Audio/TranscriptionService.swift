import AVFoundation
import Speech
import Foundation

final class TranscriptionService {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW")) ??
                             SFSpeechRecognizer(locale: .current)

    // For live streaming during recording
    private var liveRequest: SFSpeechAudioBufferRecognitionRequest?
    private var liveTask: SFSpeechRecognitionTask?

    // MARK: - Permission

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Post-recording transcription (accurate, uses file)

    func transcribe(audioFileURL: URL) async throws -> String {
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        // If Whisper is selected and OpenAI key is available, use Whisper
        if AppConfig.transcriptionBackend == .whisper && !AppConfig.openAIAPIKey.isEmpty {
            return try await transcribeWithWhisper(audioFileURL: audioFileURL)
        }

        return try await transcribeWithAppleSpeech(audioFileURL: audioFileURL)
    }

    private func transcribeWithAppleSpeech(audioFileURL: URL) async throws -> String {
        guard let recognizer else { throw TranscriptionError.recognizerUnavailable }

        let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    private func transcribeWithWhisper(audioFileURL: URL) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let audioData = try Data(contentsOf: audioFileURL)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\nwhisper-1\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TranscriptionError.whisperAPIError
        }

        struct WhisperResponse: Decodable { let text: String }
        let decoded = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return decoded.text
    }

    // MARK: - Live preview (Apple Speech only, always)

    func startLiveTranscription(audioEngine: AVAudioEngine) -> AsyncStream<String> {
        stopLiveTranscription()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        self.liveRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        return AsyncStream { continuation in
            self.liveTask = recognizer?.recognitionTask(with: request) { result, _ in
                if let text = result?.bestTranscription.formattedString {
                    continuation.yield(text)
                }
                if result?.isFinal == true {
                    continuation.finish()
                }
            }
        }
    }

    func stopLiveTranscription() {
        liveTask?.cancel()
        liveTask = nil
        liveRequest?.endAudio()
        liveRequest = nil
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case whisperAPIError

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable: return "Speech recognizer is not available."
        case .whisperAPIError:       return "Whisper API transcription failed."
        }
    }
}
