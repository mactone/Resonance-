import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @State private var viewModel = HomeViewModel()
    @State private var showRecording = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Continue listening card
                    if let article = viewModel.unfinishedArticle {
                        continueListeningCard(article)
                    }

                    // Recent articles
                    if !viewModel.recentArticles.isEmpty {
                        sectionHeader("最近的文章")
                        ForEach(viewModel.recentArticles) { article in
                            NavigationLink(value: NavigationDestination.articlePlayer(article)) {
                                ArticleCardView(article: article)
                                    .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Stats row
                    statsRow

                    // Generate button
                    if viewModel.pendingNoteCount >= AppConfig.autoAggregationMinNotes {
                        generateButton
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
            .navigationTitle("Resonance")
            .navigationDestination(for: NavigationDestination.self) { dest in
                dest.view
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    QuickCaptureButton { showRecording = true }
                }
            }
            .sheet(isPresented: $showRecording, onDismiss: { viewModel.refresh() }) {
                RecordingView()
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
                viewModel.refresh()
            }
            .refreshable { viewModel.refresh() }
        }
    }

    // MARK: - Sub-views

    private func continueListeningCard(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("繼續聆聽", systemImage: "play.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            NavigationLink(value: NavigationDestination.articlePlayer(article)) {
                ArticleCardView(article: article, showProgress: true)
                    .padding(.horizontal)
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal)
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "mic.fill",
                value: "\(viewModel.pendingNoteCount)",
                label: "待處理筆記"
            )
            StatCard(
                icon: "doc.text.fill",
                value: "\(viewModel.recentArticles.count)",
                label: "篇文章"
            )
        }
        .padding(.horizontal)
    }

    private var generateButton: some View {
        Button {
            Task { await viewModel.generateArticlesNow() }
        } label: {
            HStack {
                if viewModel.isGenerating {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                Text(viewModel.isGenerating ? "生成中..." : "立即生成文章")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .disabled(viewModel.isGenerating)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview("Home — with data") {
    let ctx = PreviewContainer.makeContext()
    return ContentView()
        .environment(AppRouter())
        .modelContainer(PreviewContainer.container)
}
