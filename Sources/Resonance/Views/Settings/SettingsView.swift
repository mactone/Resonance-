import SwiftUI
import AVFoundation
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // AI
                Section {
                    NavigationLink {
                        AIProviderSettingsView(viewModel: viewModel)
                    } label: {
                        LabeledContent("AI 提供商") {
                            Text(viewModel.selectedProvider.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("AI 設定")
                }

                // TTS
                Section("朗讀設定") {
                    if !viewModel.availableVoices.isEmpty {
                        Picker("聲音", selection: $viewModel.selectedVoiceIdentifier) {
                            Text("系統預設").tag("")
                            ForEach(viewModel.availableVoices, id: \.identifier) { voice in
                                Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                            }
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("語速: \(String(format: "%.1f", viewModel.ttsRate))")
                            .font(.subheadline)
                        Slider(value: $viewModel.ttsRate, in: 0.1...1.0, step: 0.05)
                    }
                }

                // Auto-aggregation
                Section {
                    Toggle("自動生成文章", isOn: $viewModel.autoAggregationEnabled)
                    if viewModel.autoAggregationEnabled {
                        Stepper("觸發筆記數：\(viewModel.autoAggregationMinNotes)",
                                value: $viewModel.autoAggregationMinNotes,
                                in: 2...20)
                    }
                } header: {
                    Text("自動彙整")
                } footer: {
                    Text("累積足夠筆記後，App 會在背景自動生成文章並通知你。")
                }

                // Blog platforms
                Section {
                    NavigationLink("發佈平台設定") {
                        BlogPlatformSettingsView()
                    }
                } header: {
                    Text("發佈")
                }

                // Save
                Section {
                    Button("儲存設定") { viewModel.save() }
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if let msg = viewModel.saveMessage {
                    Section {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                // About
                Section("關於") {
                    LabeledContent("版本", value: "1.0.0")
                    Link("回報問題", destination: URL(string: "https://github.com")!)
                }
            }
            .navigationTitle("設定")
            .onAppear {
                viewModel.setup(modelContext: modelContext)
            }
        }
    }
}
