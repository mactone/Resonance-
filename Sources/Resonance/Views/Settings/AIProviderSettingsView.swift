import SwiftUI

struct AIProviderSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("AI 提供商") {
                Picker("選擇 AI", selection: $viewModel.selectedProvider) {
                    ForEach(AIProviderType.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                LabeledContent("分類模型") { Text(viewModel.selectedProvider.fastModelName).foregroundStyle(.secondary) }
                LabeledContent("生成模型") { Text(viewModel.selectedProvider.qualityModelName).foregroundStyle(.secondary) }
            } header: {
                Text("使用的模型")
            }

            Section(header: Text("API 金鑰"), footer: Text("金鑰安全地儲存在 Keychain 中，不會上傳到任何伺服器。")) {
                switch viewModel.selectedProvider {
                case .claude:
                    SecureField("Anthropic API Key (sk-ant-...)", text: $viewModel.claudeKey)
                        .textContentType(.password)
                case .openai:
                    SecureField("OpenAI API Key (sk-...)", text: $viewModel.openAIKey)
                        .textContentType(.password)
                case .gemini:
                    SecureField("Google AI API Key", text: $viewModel.geminiKey)
                        .textContentType(.password)
                }
            }

            Section("語音轉文字") {
                Picker("轉錄方式", selection: $viewModel.transcriptionBackend) {
                    ForEach(TranscriptionBackend.allCases) { backend in
                        Text(backend.displayName).tag(backend)
                    }
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("AI 設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}
