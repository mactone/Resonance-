import SwiftUI

struct InterruptCaptureView: View {
    let isRecording: Bool
    let transcription: String
    let audioLevel: Float
    let onStartRecording: () async -> Void
    let onStopRecording: () async -> Void
    let onConfirm: () async -> Void
    let onDiscard: () async -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("加入新想法")
                .font(.headline)

            if isRecording {
                // Recording state
                WaveformView(level: audioLevel, color: .red)
                    .frame(height: 60)
                    .padding(.horizontal)

                Text("錄音中...").font(.subheadline).foregroundStyle(.red)

                Button {
                    Task { await onStopRecording() }
                } label: {
                    ZStack {
                        Circle().fill(Color.red).frame(width: 60, height: 60)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 22, height: 22)
                    }
                }
            } else if !transcription.isEmpty {
                // Preview transcription
                ScrollView {
                    Text(transcription)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxHeight: 120)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        Task { await onDiscard() }
                    } label: {
                        Label("丟棄並繼續", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await onConfirm() }
                    } label: {
                        Label("儲存並繼續", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            } else {
                // Ready to record
                Text("點擊麥克風加入語音筆記")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await onStartRecording() }
                } label: {
                    ZStack {
                        Circle().fill(Color.accentColor).frame(width: 60, height: 60)
                        Image(systemName: "mic.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }

                Button(role: .cancel) {
                    Task { await onDiscard() }
                } label: {
                    Text("取消，繼續播放")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
