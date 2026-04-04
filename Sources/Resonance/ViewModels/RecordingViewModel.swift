import SwiftData
import Observation
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

        let granted = await TranscriptionService.requestPermission()
        guard granted else {
            recordingState = .failed("Speech recognition permission denied.")
            return
        }

        do {
            recordingState = .recording
            try await recordingService.startRecording()
            startObservingLevel()
        } catch {
            recordingState = .failed(error.localizedDescription)
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
