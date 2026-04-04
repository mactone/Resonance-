import SwiftUI
import SwiftData

struct PublishConfirmView: View {
    let article: Article
    let viewModel: ArticlePlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @Query private var platforms: [BlogPlatformConfig]

    @State private var selectedPlatform: BlogPlatformConfig?
    @State private var asDraft = false

    var body: some View {
        NavigationStack {
            Form {
                // Article preview
                Section("文章") {
                    Text(article.title).font(.headline)
                    Text(article.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                // Platform selection
                Section("發佈到") {
                    if platforms.isEmpty {
                        Text("尚未設定發佈平台")
                            .foregroundStyle(.secondary)
                        NavigationLink("前往設定") {
                            BlogPlatformSettingsView()
                        }
                    } else {
                        ForEach(platforms) { platform in
                            HStack {
                                Label(platform.displayName, systemImage: platform.platformType.iconName)
                                Spacer()
                                if selectedPlatform?.id == platform.id {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { selectedPlatform = platform }
                        }
                    }
                }

                // Options
                Section {
                    Toggle("儲存為草稿", isOn: $asDraft)
                }

                // Publish
                Section {
                    Button {
                        guard let platform = selectedPlatform else { return }
                        Task {
                            await viewModel.publish(config: platform, asDraft: asDraft)
                            if viewModel.publishedURL != nil { dismiss() }
                        }
                    } label: {
                        HStack {
                            if viewModel.isPublishing { ProgressView().scaleEffect(0.8) }
                            Text(asDraft ? "發佈為草稿" : "立即發佈")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .disabled(selectedPlatform == nil || viewModel.isPublishing)
                }

                if let err = viewModel.errorMessage {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("發佈文章")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                selectedPlatform = platforms.first(where: { $0.isDefault }) ?? platforms.first
            }
        }
    }
}
