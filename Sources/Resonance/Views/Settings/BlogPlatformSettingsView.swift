import SwiftUI

struct BlogPlatformSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var showAddSheet = false

    var body: some View {
        List {
            if viewModel.blogPlatforms.isEmpty {
                ContentUnavailableView(
                    "還沒有發佈平台",
                    systemImage: "globe.badge.chevron.backward",
                    description: Text("點擊右上角 + 新增平台")
                )
            } else {
                ForEach(viewModel.blogPlatforms) { platform in
                    PlatformRow(
                        platform: platform,
                        isValid: viewModel.validationStatus[platform.id],
                        onValidate: {
                            Task { await viewModel.validatePlatform(platform) }
                        },
                        onSetDefault: { viewModel.setDefaultPlatform(platform) }
                    )
                }
                .onDelete { indexSet in
                    for i in indexSet { viewModel.deletePlatform(viewModel.blogPlatforms[i]) }
                }
            }
        }
        .navigationTitle("發佈平台")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: { viewModel.loadBlogPlatforms() }) {
            AddPlatformView(onAdd: { type, name, url, username, key in
                viewModel.addPlatform(type: type, displayName: name, blogURL: url, username: username, apiKey: key)
            })
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
        }
    }
}

// MARK: - Platform Row

private struct PlatformRow: View {
    let platform: BlogPlatformConfig
    let isValid: Bool?
    let onValidate: () -> Void
    let onSetDefault: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(platform.displayName, systemImage: platform.platformType.iconName)
                    .font(.headline)
                Spacer()
                if platform.isDefault {
                    Text("預設")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
            Text(platform.blogURL)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if let valid = isValid {
                    Label(valid ? "驗證成功" : "驗證失敗",
                          systemImage: valid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(valid ? .green : .red)
                }

                Spacer()

                Button("驗證", action: onValidate)
                    .font(.caption)
                    .buttonStyle(.bordered)

                if !platform.isDefault {
                    Button("設為預設", action: onSetDefault)
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}

// MARK: - Add Platform Sheet

private struct AddPlatformView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (BlogPlatform, String, String, String, String) -> Void

    @State private var platformType: BlogPlatform = .wordpress
    @State private var displayName = ""
    @State private var blogURL = ""
    @State private var username = ""
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("平台") {
                    Picker("類型", selection: $platformType) {
                        ForEach(BlogPlatform.allCases) { p in
                            Label(p.displayName, systemImage: p.iconName).tag(p)
                        }
                    }
                }

                Section("資訊") {
                    TextField("顯示名稱（如：我的部落格）", text: $displayName)
                    TextField(urlPlaceholder, text: $blogURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if platformType != .substack {
                        TextField("帳號 / 使用者名稱", text: $username)
                    }
                }

                Section(header: Text("憑證"), footer: Text(keyNote)) {
                    SecureField(keyPlaceholder, text: $apiKey)
                        .textContentType(.password)
                }
            }
            .navigationTitle("新增平台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新增") {
                        onAdd(platformType, displayName, blogURL, username, apiKey)
                        dismiss()
                    }
                    .disabled(displayName.isEmpty || blogURL.isEmpty || apiKey.isEmpty)
                }
            }
        }
    }

    private var urlPlaceholder: String {
        switch platformType {
        case .wordpress: return "https://yourblog.com"
        case .substack:  return "yourpublication@substack.com"
        case .vocus:     return "你的 vocus 出版品網址"
        }
    }

    private var keyPlaceholder: String {
        switch platformType {
        case .wordpress: return "應用程式密碼 (App Password)"
        case .substack:  return "（Substack 使用 Email，無需 API Key）"
        case .vocus:     return "Bearer Token"
        }
    }

    private var keyNote: String {
        switch platformType {
        case .wordpress: return "WordPress → 使用者設定 → 應用程式密碼"
        case .substack:  return "輸入任意文字（Substack 使用 Email 發佈）"
        case .vocus:     return "vocus.cc → 帳號設定 → API Token"
        }
    }
}
