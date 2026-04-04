import AVFoundation
import Observation
import Foundation

@Observable
final class AudioRecordingService: NSObject {
    var isRecording: Bool = false
    var currentLevel: Float = 0.0        // 0.0 – 1.0 normalised, drives WaveformView
    var recordingDuration: TimeInterval = 0.0
    var currentFileURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var startTime: Date?

    // MARK: - Start

    func startRecording() async throws {
        try await AudioSessionManager.shared.activateForRecording()

        let url = AudioFileManager.shared.newRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey:              Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey:            Constants.Audio.sampleRate,
            AVNumberOfChannelsKey:      Constants.Audio.channels,
            AVEncoderAudioQualityKey:   AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.delegate = self
        recorder.record()

        self.audioRecorder = recorder
        self.currentFileURL = url
        self.startTime = .now
        self.isRecording = true

        startLevelTimer()
    }

    // MARK: - Stop

    @discardableResult
    func stopRecording() async throws -> URL {
        guard let recorder = audioRecorder, let url = currentFileURL else {
            throw RecordingError.notRecording
        }

        stopLevelTimer()
        recorder.stop()
        isRecording = false
        currentLevel = 0
        audioRecorder = nil

        try? await AudioSessionManager.shared.deactivate()

        return url
    }

    // MARK: - Discard

    func discardRecording() {
        stopLevelTimer()
        audioRecorder?.stop()
        if let url = currentFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        audioRecorder = nil
        currentFileURL = nil
        isRecording = false
        currentLevel = 0
        recordingDuration = 0
    }

    // MARK: - Level Metering

    private func startLevelTimer() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateLevel()
        }
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func updateLevel() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        // averagePower is in dB (-160 to 0); normalise to 0–1
        let db = recorder.averagePower(forChannel: 0)
        let normalised = max(0, (db + 60) / 60)
        currentLevel = normalised
        if let start = startTime {
            recordingDuration = Date().timeIntervalSince(start)
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingService: AVAudioRecorderDelegate {
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        isRecording = false
        stopLevelTimer()
    }
}

// MARK: - Errors

enum RecordingError: LocalizedError {
    case notRecording
    case fileCreationFailed

    var errorDescription: String? {
        switch self {
        case .notRecording:       return "No active recording."
        case .fileCreationFailed: return "Failed to create recording file."
        }
    }
}
