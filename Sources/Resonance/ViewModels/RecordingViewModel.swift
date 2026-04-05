import SwiftData
import Observation
import AVFoundation
import Foundation

@Observable
final class RecordingViewModel {
    enum RecordingState {
        case idle, requestingPermission, recording, processing, saved, failed(String)
    }

    var recordingState: RecordingState = .idle
    var liveTranscription: String = ""
    var audioLevel: Float = 0.0
    var elapsedTime: TimeInterval = 0.0
    var savedNote: VoiceNote?

    private let recordingService = AudioRecordingService()
    private let transcriptionService = TranscriptionService()
    private var levelObservationTask: Task<Void, Never>?
    private var modelContext: ModelContext?

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Recording

    func startRecording() async {
        guard case .idle = recordingState else { return }
        recordingState = .requestingPermission

        // 1. Microphone permission (required before AVAudioRecorder can start)
        let micGranted = await requestMicrophonePermission()
        guard micGranted else {
            recordingState = .failed("需要麥克風權限。請前往「設定 → 隱私權 → 麥克風」開啟 Resonance 的存取。")
            return
        }

        // 2. Speech recognition permission (for transcription — non-fatal if denied)
        let _ = await TranscriptionService.requestPermission()

        do {
            recordingState = .recording
            try await recordingService.startRecording()
            startObservingLevel()
        } catch {
            recordingState = .failed("無法開始錄音：\(error.localizedDescription)")
        }
    }

    // MARK: - Permission helpers

    private func requestMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    func stopRecording() async {
        guard case .recording = recordingState else { return }
        stopObservingLevel()
        recordingState = .processing

        do {
            let url = try await recordingService.stopRecording()
            let transcription = try await transcriptionService.transcribe(audioFileURL: url)
            liveTranscription = transcription

            let note = VoiceNote(
                rawTranscription: transcription,
                recordedAt: .now,
                durationSeconds: recordingService.recordingDuration
            )
            note.audioFileName = url.lastPathComponent
            note.isTranscribed = true

            modelContext?.insert(note)
            try modelContext?.save()

            savedNote = note
            recordingState = .saved
        } catch {
            recordingState = .failed(error.localizedDescription)
        }
    }

    func discardRecording() {
        stopObservingLevel()
        recordingService.discardRecording()
        liveTranscription = ""
        elapsedTime = 0
        audioLevel = 0
        recordingState = .idle
    }

    func reset() {
        savedNote = nil
        liveTranscription = ""
        elapsedTime = 0
        audioLevel = 0
        recordingState = .idle
    }

    // MARK: - Level Observation

    private func startObservingLevel() {
        levelObservationTask = Task { @MainActor in
            while !Task.isCancelled {
                self.audioLevel = self.recordingService.currentLevel
                self.elapsedTime = self.recordingService.recordingDuration
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    private func stopObservingLevel() {
        levelObservationTask?.cancel()
        levelObservationTask = nil
        audioLevel = 0
    }

    // MARK: - Categorisation (runs async after save, doesn't block UI)

    func runCategorizationIfNeeded(for note: VoiceNote, existingCategories: [NoteCategory]) {
        guard !note.isCategorized else { return }
        Task {
            do {
                let provider = try AIProviderFactory.makeFastProvider()
                let service = CategorizationService(provider: provider)
                let result = try await service.categorize(
                    transcription: note.rawTranscription,
                    existingCategories: existingCategories
                )

                note.cleanedTranscription = result.cleanedText

                // Find or create category
                let cat = existingCategories.first(where: { $0.name.lowercased() == result.categoryName.lowercased() })
                    ?? createCategory(name: result.categoryName, icon: result.categoryIcon, color: result.colorHex)

                note.category = cat
                note.isCategorized = true
                try modelContext?.save()
            } catch {
                // Categorisation failure is non-fatal; note is still saved
            }
        }
    }

    private func createCategory(name: String, icon: String, color: String) -> NoteCategory {
        let cat = NoteCategory(name: name, colorHex: color, systemIconName: icon)
        modelContext?.insert(cat)
        return cat
    }
}
