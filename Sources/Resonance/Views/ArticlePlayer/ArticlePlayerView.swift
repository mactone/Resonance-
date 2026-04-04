import SwiftUI
import SwiftData

struct ArticlePlayerView: View {
    @Environment(\.modelContext) private var modelContext
    let article: Article

    @State private var viewModel: ArticlePlayerViewModel
    @State private var showPublish = false

    init(article: Article) {
        self.article = article
        _viewModel = State(initialValue: ArticlePlayerViewModel(article: article))
    }

    private var tts: TTSService { viewModel.coordinator.ttsService }
    private var coordinator: PlaybackCoordinator { viewModel.coordinator }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        if let cat = article.category {
                            Label(cat.name, systemImage: cat.systemIconName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: cat.colorHex) ?? .accentColor)
                        }
                        Text(article.title)
                            .font(.largeTitle.bold())
                        Text(article.generatedAt.formatted(date: .long, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    Divider()

                    // Article body with segment highlighting
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(article.sortedSegments.enumerated()), id: \.element.id) { index, seg in
                            Text(seg.text)
                                .font(.body)
                                .lineSpacing(6)
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                .background(
                                    index == tts.currentSegmentIndex && tts.isPlaying
                                        ? Color.accentColor.opacity(0.08)
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .animation(.easeInOut(duration: 0.3), value: tts.currentSegmentIndex)
                        }
                    }
                    .padding(.vertical)

                    Spacer(minLength: 200) // space for controls overlay
                }
            }

            // Interrupt capture overlay
            if viewModel.isInterruptCaptureActive || coordinator.isInterrupted {
                InterruptCaptureView(
                    isRecording: coordinator.isCapturingNote,
                    transcription: viewModel.interruptTranscription,
                    audioLevel: coordinator.recordingService.currentLevel,
                    onStartRecording: { await viewModel.beginInterruptCapture() },
                    onStopRecording: { await viewModel.stopInterruptCapture() },
                    onConfirm: { await viewModel.confirmInterruptNote() },
                    onDiscard: { await viewModel.discardInterruptNote() }
                )
                .frame(maxHeight: 320)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }

            // Playback controls bar
            if !coordinator.isInterrupted {
                playbackControls
                    .transition(.move(edge: .bottom))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(article.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showPublish = true
                    } label: {
                        Label("發佈文章", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showPublish) {
            PublishConfirmView(article: article, viewModel: viewModel)
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
        }
        .onDisappear {
            viewModel.stop()
        }
        .animation(.spring(response: 0.35), value: coordinator.isInterrupted)
    }

    // MARK: - Controls

    private var playbackControls: some View {
        VStack(spacing: 12) {
            PlaybackProgressView(
                currentSegment: tts.currentSegmentIndex,
                totalSegments: article.segments.count,
                segmentProgress: tts.progressFraction,
                onSeek: { viewModel.seekToSegment($0) }
            )

            HStack(spacing: 32) {
                // Skip back
                Button { viewModel.seekToSegment(max(0, tts.currentSegmentIndex - 1)) } label: {
                    Image(systemName: "backward.fill").font(.title2)
                }

                // Play / Pause
                Button {
                    if tts.isPlaying {
                        viewModel.pause()
                    } else if tts.isPaused {
                        viewModel.resume()
                    } else {
                        viewModel.play()
                    }
                } label: {
                    Image(systemName: tts.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.accentColor)
                }

                // Skip forward
                Button {
                    viewModel.seekToSegment(min(article.segments.count - 1, tts.currentSegmentIndex + 1))
                } label: {
                    Image(systemName: "forward.fill").font(.title2)
                }

                // Interrupt mic
                Button {
                    Task { await viewModel.beginInterruptCapture() }
                } label: {
                    Image(systemName: "mic.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
