import SwiftUI

// MARK: - ArticlePlayerView Preview

#Preview("Article Player") {
    let ctx = PreviewContainer.makeContext()
    let articles = try! ctx.fetch(.init(Article.self))
    let article = articles.first!
    return NavigationStack {
        ArticlePlayerView(article: article)
    }
    .environment(AppRouter())
    .modelContainer(PreviewContainer.container)
}

// MARK: - RecordingView Previews

#Preview("Recording — waveform") {
    // Simulate active recording state by wrapping in a ZStack
    ZStack {
        Color(.systemBackground)
        VStack(spacing: 24) {
            Text("00:23")
                .font(.system(size: 48, weight: .light, design: .monospaced))
            WaveformView(level: 0.65)
                .frame(height: 80)
                .padding(.horizontal, 32)
            Text("今天在三峽跑步的時候，突然想到...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            ZStack {
                Circle().fill(Color.red).frame(width: 72, height: 72)
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white)
                    .frame(width: 26, height: 26)
            }
        }
    }
}

// MARK: - WaveformView Preview

#Preview("Waveform — various levels") {
    VStack(spacing: 20) {
        ForEach([0.1, 0.3, 0.6, 0.9], id: \.self) { level in
            VStack(alignment: .leading) {
                Text("Level: \(level, specifier: "%.1f")")
                    .font(.caption).foregroundStyle(.secondary)
                WaveformView(level: Float(level))
                    .frame(height: 50)
            }
        }
    }
    .padding()
}

// MARK: - InterruptCaptureView Preview

#Preview("Interrupt Capture — ready") {
    InterruptCaptureView(
        isRecording: false,
        transcription: "",
        audioLevel: 0,
        onStartRecording: {},
        onStopRecording: {},
        onConfirm: {},
        onDiscard: {}
    )
    .frame(maxHeight: 300)
    .padding()
}

#Preview("Interrupt Capture — transcribed") {
    InterruptCaptureView(
        isRecording: false,
        transcription: "等等，我想補充一點，其實間歇跑比長跑對創意思考的效果更好，因為它的高強度間隔更能刺激腦內啡分泌。",
        audioLevel: 0,
        onStartRecording: {},
        onStopRecording: {},
        onConfirm: {},
        onDiscard: {}
    )
    .frame(maxHeight: 300)
    .padding()
}
