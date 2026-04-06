import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @State private var viewModel = LibraryViewModel()
    @State private var selectedTab = 0
    @State private var showAggregation = false
    @State private var showRecording = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                CategoryFilterView(
                    categories: viewModel.categories,
                    selectedCategory: $viewModel.selectedCategory
                )
                .padding(.vertical, 8)
                .onChange(of: viewModel.selectedCategory) { viewModel.refresh() }

                // Tab selector
                Picker("", selection: $selectedTab) {
                    Text("文章").tag(0)
                    Text("筆記").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Content
                if selectedTab == 0 {
                    articlesList
                } else {
                    notesList
                }
            }
            .navigationTitle("資料庫")
            .navigationDestination(for: NavigationDestination.self) { dest in
                dest.view
            }
            .searchable(text: $viewModel.searchText, prompt: "搜尋筆記...")
            .onChange(of: viewModel.searchText) { viewModel.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showRecording = true
                        } label: {
                            Label("錄製新筆記", systemImage: "mic.fill")
                        }
                        Button {
                            showAggregation = true
                        } label: {
                            Label("手動生成文章", systemImage: "wand.and.stars")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showRecording, onDismiss: { viewModel.refresh() }) {
                RecordingView()
            }
            .sheet(isPresented: $showAggregation, onDismiss: { viewModel.refresh() }) {
                AggregationView()
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
                viewModel.refresh()
            }
            .refreshable { viewModel.refresh() }
        }
    }

    // MARK: - Articles List

    private var articlesList: some View {
        Group {
            if viewModel.articles.isEmpty {
                emptyState(
                    icon: "doc.text",
                    title: "還沒有文章",
                    subtitle: "累積筆記後，點擊「手動生成文章」或等待自動生成"
                )
            } else {
                List {
                    ForEach(viewModel.articles) { article in
                        NavigationLink(value: NavigationDestination.articlePlayer(article)) {
                            ArticleCardView(article: article)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        for i in indexSet { viewModel.deleteArticle(viewModel.articles[i]) }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Notes List

    private var notesList: some View {
        Group {
            if viewModel.notes.isEmpty {
                emptyState(
                    icon: "mic",
                    title: "還沒有筆記",
                    subtitle: "點擊麥克風按鈕，用語音記錄你的第一個閃念"
                )
            } else {
                List {
                    ForEach(viewModel.notes) { note in
                        VoiceNoteRowView(note: note)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        for i in indexSet { viewModel.deleteNote(viewModel.notes[i]) }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text(title).font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Library") {
    let _ = PreviewContainer.makeContext()
    return LibraryView()
        .environment(AppRouter())
        .modelContainer(PreviewContainer.container)
}
