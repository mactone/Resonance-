import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [NoteCategory]

    @State private var viewModel = RecordingViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                switch viewModel.recordingState {
                case .idle:
                    readyView
                case .requestingPermission:
                    ProgressView("請求權限中...")
                case .recording:
                    recordingActiveView
                case .processing:
                    processingView
                case .saved:
                    if !viewModel.liveTranscription.isEmpty {
                        TranscriptionPreviewView(
                            transcription: viewModel.liveTranscription,
                            onSave: {
                                if let note = viewModel.savedNote {
                                    viewModel.runCategorizationIfNeeded(for: note, existingCategories: categories)
                                }
                                dismiss()
                            },
                            onDiscard: {
                                if let note = viewModel.savedNote {
                                    modelContext.delete(note)
                                    try? modelContext.save()
                                }
                                viewModel.reset()
                            }
                        )
                    }
                case .failed(let msg):
                    errorView(msg)
                }
            }
            .navigationTitle("錄製閃念")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { viewModel.setup(modelContext: modelContext) }
        }
    }

    // MARK: - Sub-views

    private var readyView: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "mic.circle")
                .font(.system(size: 80))
                .foregroundStyle(.accentColor)
            Text("點擊下方按鈕開始錄音")
                .foregroundStyle(.secondary)
            Spacer()
            recordButton
                .padding(.bottom, 40)
        }
    }

    private var recordingActiveView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Timer
            Text(timeString(viewModel.elapsedTime))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(.primary)

            // Waveform
            WaveformView(level: viewModel.audioLevel)
                .frame(height: 80)
                .padding(.horizontal, 32)

            // Live transcription preview
            if !viewModel.liveTranscription.isEmpty {
                Text(viewModel.liveTranscription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal)
                    .animation(.default, value: viewModel.liveTranscription)
            }

            Spacer()

            // Stop button
            Button {
                Task { await viewModel.stopRecording() }
            } label: {
                ZStack {
                    Circle().fill(Color.red).frame(width: 72, height: 72)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white)
                        .frame(width: 26, height: 26)
                }
            }
            .padding(.bottom, 40)
        }
    }

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("轉錄中...")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.red)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("重試") { viewModel.reset() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var recordButton: some View {
        QuickCaptureButton {
            Task { await viewModel.startRecording() }
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
