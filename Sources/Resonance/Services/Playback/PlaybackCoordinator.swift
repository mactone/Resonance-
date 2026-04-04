import Observation
import Foundation

/// Orchestrates the state machine for TTS playback, including mid-playback voice capture.
@Observable
final class PlaybackCoordinator {
    enum State: Equatable {
        case idle
        case playing(articleID: UUID)
        case paused(articleID: UUID)
        case interruptedForCapture(articleID: UUID, resumeState: TTSPlaybackState)
        case addingNote(articleID: UUID, resumeState: TTSPlaybackState)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.playing(let a), .playing(let b)): return a == b
            case (.paused(let a), .paused(let b)): return a == b
            case (.interruptedForCapture(let a, _), .interruptedForCapture(let b, _)): return a == b
            case (.addingNote(let a, _), .addingNote(let b, _)): return a == b
            default: return false
            }
        }
    }

    private(set) var state: State = .idle

    let ttsService: TTSService
    let recordingService: AudioRecordingService

    init(ttsService: TTSService, recordingService: AudioRecordingService) {
        self.ttsService = ttsService
        self.recordingService = recordingService
    }

    // MARK: - Playback

    func startPlayback(article: Article) async throws {
        ttsService.load(article: article)
        state = .playing(articleID: article.id)
        try await ttsService.play()
        // play() returns when article finishes
        state = .idle
    }

    func pause(articleID: UUID) {
        ttsService.pause()
        state = .paused(articleID: articleID)
    }

    func resume(articleID: UUID) {
        ttsService.resume()
        state = .playing(articleID: articleID)
    }

    // MARK: - Interrupt for Note Capture

    func beginInterruptCapture(articleID: UUID) async throws {
        let resumeState = ttsService.pauseForInterruption()
        state = .interruptedForCapture(articleID: articleID, resumeState: resumeState)

        try await recordingService.startRecording()
        state = .addingNote(articleID: articleID, resumeState: resumeState)
    }

    func endInterruptCapture() async throws -> URL? {
        guard case .addingNote(let articleID, let resumeState) = state else { return nil }

        let url = try await recordingService.stopRecording()
        state = .interruptedForCapture(articleID: articleID, resumeState: resumeState)
        return url
    }

    func confirmAndResumePlayback() async throws {
        guard case .interruptedForCapture(let articleID, let resumeState) = state else { return }
        state = .playing(articleID: articleID)
        try await ttsService.restoreFromInterruption(resumeState)
    }

    func discardAndResumePlayback() async throws {
        guard case .interruptedForCapture(let articleID, let resumeState) = state else { return }
        recordingService.discardRecording()
        state = .playing(articleID: articleID)
        try await ttsService.restoreFromInterruption(resumeState)
    }

    func stopPlayback() {
        ttsService.stop()
        state = .idle
    }

    // MARK: - Helpers

    var currentArticleID: UUID? {
        switch state {
        case .idle:                              return nil
        case .playing(let id):                   return id
        case .paused(let id):                    return id
        case .interruptedForCapture(let id, _):  return id
        case .addingNote(let id, _):             return id
        }
    }

    var isCapturingNote: Bool {
        if case .addingNote = state { return true }
        return false
    }

    var isInterrupted: Bool {
        if case .interruptedForCapture = state { return true }
        if case .addingNote = state { return true }
        return false
    }
}
