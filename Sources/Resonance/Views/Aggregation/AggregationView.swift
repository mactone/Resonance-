import SwiftUI
import SwiftData

struct AggregationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    @State private var viewModel = AggregationViewModel()
    @State private var showNoteSelector = false

    var body: some View {
        NavigationStack {
            Form {
                // Category picker
                Section("主題分類") {
                    Picker("分類", selection: $viewModel.selectedCategory) {
                        Text("不限").tag(NoteCategory?.none)
                        ForEach(viewModel.categories) { cat in
                            Label(cat.name, systemImage: cat.systemIconName)
                                .tag(NoteCategory?.some(cat))
                        }
                    }
                }

                // Selected notes
                Section {
                    if viewModel.selectedNoteIDs.isEmpty {
                        Text("尚未選擇筆記")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("已選擇 \(viewModel.selectedNoteIDs.count) 篇筆記")
                            .foregroundStyle(Color.accentColor)
                    }

                    Button("選擇筆記") { showNoteSelector = true }
                } header: {
                    Text("選擇筆記")
                } footer: {
                    Text("選擇你想串聯成文章的語音筆記")
                }

                // Generate button
                if !viewModel.selectedNoteIDs.isEmpty {
                    Section {
                        Button {
                            Task { await viewModel.generateArticle() }
                        } label: {
                            HStack {
                                if viewModel.isGenerating {
                                    ProgressView().scaleEffect(0.8)
                                    Text("生成中... \(Int(viewModel.generationProgress * 100))%")
                                } else {
                                    Label("生成文章", systemImage: "wand.and.stars")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .disabled(viewModel.isGenerating)
                    }
                }

                // Preview result
                if !viewModel.generatedArticleTitle.isEmpty {
                    Section("預覽") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.generatedArticleTitle)
                                .font(.headline)
                            Text(viewModel.generatedArticleBody.prefix(400) + "…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Button("重新生成") {
                                Task { await viewModel.regenerate() }
                            }
                            Spacer()
                            Button("儲存並查看") {
                                if let article = viewModel.generatedArticle {
                                    dismiss()
                                    router.navigateTo(.articlePlayer(article))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                // Error
                if let err = viewModel.errorMessage {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("手動生成文章")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("全選") { viewModel.selectAll() }
                }
            }
            .sheet(isPresented: $showNoteSelector) {
                NavigationStack {
                    NoteSelectionView(
                        notes: viewModel.availableNotes,
                        selectedIDs: $viewModel.selectedNoteIDs
                    )
                    .navigationTitle("選擇筆記")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") { showNoteSelector = false }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
                viewModel.loadNotes()
            }
        }
    }
}
