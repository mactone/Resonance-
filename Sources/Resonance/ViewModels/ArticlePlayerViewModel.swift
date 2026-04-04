import SwiftData
import Observation
import Foundation

@Observable
final class ArticlePlayerViewModel {
    var article: Article
    var isInterruptCaptureActive: Bool = false
    var interruptTranscription: String = ""
    var errorMessage: String?
    var isPublishing: Bool = false
    var publishedURL: URL?

    let coordinator: PlaybackCoordinator
    private var modelContext: ModelContext?
    private var playbackTask: Task<Void, Never>?

    init(article: Article) {
        self.article = article
        let tts = TTSService()
        let recording = AudioRecordingService()
        coordinator = PlaybackCoordinator(ttsService: tts, recordingService: recording)
    }

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Playback

    func play() {
        guard playbackTask == nil else { return }
        playbackTask = Task {
            do {
                try await coordinator.startPlayback(article: article)
                article.isFullyRead = coordinator.ttsService.currentSegmentIndex >= article.segments.count - 1
                saveProgress()
            } catch {
                errorMessage = error.localizedDescription
            }
            playbackTask = nil
        }
    }

    func pause() {
        guard let id = coordinator.currentArticleID else { return }
        coordinator.pause(articleID: id)
        saveProgress()
    }

    func resume() {
        guard let id = coordinator.currentArticleID else { return }
        coordinator.resume(articleID: id)
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        coordinator.stopPlayback()
        saveProgress()
    }

    func seekToSegment(_ index: Int) {
        coordinator.ttsService.skipToSegment(index)
    }

    // MARK: - Interrupt Capture

    func beginInterruptCapture() async {
        guard let id = coordinator.currentArticleID ?? (article.id as UUID?) else { return }
        do {
            try await coordinator.beginInterruptCapture(articleID: id)
            isInterruptCaptureActive = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopInterruptCapture() async {
        do {
            guard let url = try await coordinator.endInterruptCapture() else { return }
            let transcription = try await TranscriptionService().transcribe(audioFileURL: url)
            interruptTranscription = transcription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmInterruptNote() async {
        guard let ctx = modelContext else { return }
        let note = VoiceNote(rawTranscription: interruptTranscription, recordedAt: .now)
        note.isTranscribed = true
        ctx.insert(note)
        try? ctx.save()

        isInterruptCaptureActive = false
        interruptTranscription = ""

        do {
            try await coordinator.confirmAndResumePlayback()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func discardInterruptNote() async {
        isInterruptCaptureActive = false
        interruptTranscription = ""
        do {
            try await coordinator.discardAndResumePlayback()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Publishing

    func publish(config: BlogPlatformConfig, asDraft: Bool) async {
        isPublishing = true
        errorMessage = nil
        do {
            let publisher = BlogPublisherFactory.publisher(for: config)
            let result = try await publisher.publish(article: article, config: config, asDraft: asDraft)
            article.publishStatus = .published
            article.publishedURL = result.url
            article.publishedAt = result.publishedAt
            publishedURL = result.url
            try? modelContext?.save()
        } catch {
            article.publishStatus = .failed
            errorMessage = error.localizedDescription
        }
        isPublishing = false
    }

    // MARK: - Progress

    private func saveProgress() {
        article.lastPlayedAt = .now
        article.playbackPositionSeconds = Double(coordinator.ttsService.currentSegmentIndex)
        try? modelContext?.save()
    }
}
