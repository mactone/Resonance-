import SwiftUI

struct PlaybackProgressView: View {
    let currentSegment: Int
    let totalSegments: Int
    let segmentProgress: Double   // 0–1 within current segment
    let onSeek: (Int) -> Void

    private var overallProgress: Double {
        guard totalSegments > 0 else { return 0 }
        return (Double(currentSegment) + segmentProgress) / Double(totalSegments)
    }

    var body: some View {
        VStack(spacing: 6) {
            ProgressView(value: overallProgress)
                .tint(.accentColor)

            HStack {
                Text("第 \(currentSegment + 1) 段，共 \(totalSegments) 段")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(overallProgress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}
