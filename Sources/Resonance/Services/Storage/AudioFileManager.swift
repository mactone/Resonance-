import Foundation

final class AudioFileManager {
    static let shared = AudioFileManager()
    private init() {}

    private var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Returns a new unique URL for a recording file.
    func newRecordingURL() -> URL {
        let filename = "\(UUID().uuidString).\(Constants.Audio.recordingFormat)"
        return recordingsDirectory.appendingPathComponent(filename)
    }

    /// Resolves a stored filename back to a full URL.
    func url(for filename: String) -> URL {
        recordingsDirectory.appendingPathComponent(filename)
    }

    func delete(filename: String) {
        let url = url(for: filename)
        try? FileManager.default.removeItem(at: url)
    }

    func totalRecordingsSizeBytes() -> Int64 {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return urls.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return sum + Int64(size)
        }
    }
}
