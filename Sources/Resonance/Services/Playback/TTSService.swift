import AVFoundation
import Observation
import Foundation

// MARK: - Playback State (for interrupt/resume)

struct TTSPlaybackState {
    let segmentIndex: Int
    let characterOffset: Int    // offset within segment text to resume from
}

// MARK: - TTSService

@Observable
final class TTSService: NSObject {
    var isPlaying: Bool = false
    var isPaused: Bool = false
    var currentSegmentIndex: Int = 0
    var progressFraction: Double = 0.0  // 0–1 within current segment

    private let synthesizer = AVSpeechSynthesizer()
    private var segments: [ArticleSegment] = []
    private var lastSpokenRange: NSRange?
    private var finishContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Load

    func load(article: Article) {
        stop()
        segments = article.sortedSegments
        currentSegmentIndex = 0
        progressFraction = 0
    }

    // MARK: - Play / Pause / Resume / Stop

    func play() async throws {
        guard !segments.isEmpty else { return }
        try await AudioSessionManager.shared.activateForPlayback()

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.finishContinuation = cont
            speakSegment(at: currentSegmentIndex)
        }
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
        isPlaying = false
    }

    func resume() {
        synthesizer.continueSpeaking()
        isPaused = false
        isPlaying = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        finishContinuation?.resume()
        finishContinuation = nil
    }

    func skipToSegment(_ index: Int) {
        guard index < segments.count else { return }
        synthesizer.stopSpeaking(at: .immediate)
        currentSegmentIndex = index
        lastSpokenRange = nil
        progressFraction = 0
        if isPlaying { speakSegment(at: index) }
    }

    // MARK: - Interrupt & Restore

    /// Pauses TTS cleanly at a word boundary and returns the current playback position.
    func pauseForInterruption() -> TTSPlaybackState {
        synthesizer.pauseSpeaking(at: .word)
        isPlaying = false
        isPaused = true
        let offset = lastSpokenRange.map { $0.upperBound } ?? 0
        return TTSPlaybackState(segmentIndex: currentSegmentIndex, characterOffset: offset)
    }

    /// Resumes TTS from a previously saved position.
    func restoreFromInterruption(_ state: TTSPlaybackState) async throws {
        guard state.segmentIndex < segments.count else { return }
        currentSegmentIndex = state.segmentIndex
        let segment = segments[state.segmentIndex]

        try await AudioSessionManager.shared.activateForPlayback()

        let text = segment.text
        let startOffset = min(state.characterOffset, text.count)
        let resumeText: String
        if startOffset > 0 && startOffset < text.count {
            resumeText = String(text[text.index(text.startIndex, offsetBy: startOffset)...])
        } else {
            resumeText = text
        }

        let utterance = makeUtterance(text: resumeText)
        isPlaying = true
        isPaused = false
        synthesizer.speak(utterance)
    }

    // MARK: - Private

    private func speakSegment(at index: Int) {
        guard index < segments.count else {
            finishContinuation?.resume()
            finishContinuation = nil
            isPlaying = false
            return
        }
        currentSegmentIndex = index
        lastSpokenRange = nil
        progressFraction = 0
        let utterance = makeUtterance(text: segments[index].text)
        isPlaying = true
        synthesizer.speak(utterance)
    }

    private func makeUtterance(text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AppConfig.ttsRate
        if !AppConfig.ttsVoiceIdentifier.isEmpty {
            utterance.voice = AVSpeechSynthesisVoice(identifier: AppConfig.ttsVoiceIdentifier)
        }
        utterance.pitchMultiplier = 1.0
        return utterance
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isPlaying = true
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        segments[safe: currentSegmentIndex]?.isSpoken = true
        let nextIndex = currentSegmentIndex + 1
        if nextIndex < segments.count {
            speakSegment(at: nextIndex)
        } else {
            isPlaying = false
            finishContinuation?.resume()
            finishContinuation = nil
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        lastSpokenRange = characterRange
        if utterance.speechString.count > 0 {
            progressFraction = Double(characterRange.upperBound) / Double(utterance.speechString.count)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        isPlaying = false
        isPaused = true
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        isPlaying = true
        isPaused = false
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
