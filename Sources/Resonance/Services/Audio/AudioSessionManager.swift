import AVFoundation
import Foundation

// MARK: - Events

enum AudioSessionEvent {
    case interrupted(wasSuspended: Bool)
    case resumed
    case routeChanged(reason: AVAudioSession.RouteChangeReason)
}

// MARK: - AudioSessionManager

/// Thread-safe singleton actor that owns the shared `AVAudioSession`.
/// All audio consumers (recording, TTS) must go through this to avoid conflicts.
actor AudioSessionManager {
    static let shared = AudioSessionManager()
    private init() {
        setupNotifications()
    }

    enum SessionMode {
        case idle, recording, playback, interruptedByCall
    }

    private(set) var currentMode: SessionMode = .idle
    private var eventContinuations: [UUID: AsyncStream<AudioSessionEvent>.Continuation] = [:]

    // MARK: - Activation

    func activateForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        // .allowBluetooth not available in simulator; use a try? fallback
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        } catch {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        }
        try session.setActive(true)
        currentMode = .recording
    }

    func activateForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth])
        } catch {
            try session.setCategory(.playback, mode: .spokenAudio)
        }
        try session.setActive(true)
        currentMode = .playback
    }

    func deactivate() {
        // Non-throwing: deactivation failure is non-fatal
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        currentMode = .idle
    }

    // MARK: - Event Stream

    func makeEventStream() -> AsyncStream<AudioSessionEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            eventContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeStream(id: id) }
            }
        }
    }

    private func removeStream(id: UUID) {
        eventContinuations.removeValue(forKey: id)
    }

    private func emit(_ event: AudioSessionEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    // MARK: - Notifications (must be called on nonisolated context)

    nonisolated private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let self else { return }
            Task { await self.handleInterruption(note) }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let self else { return }
            Task { await self.handleRouteChange(note) }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            currentMode = .interruptedByCall
            emit(.interrupted(wasSuspended: false))
        case .ended:
            emit(.resumed)
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }
        emit(.routeChanged(reason: reason))
    }
}
