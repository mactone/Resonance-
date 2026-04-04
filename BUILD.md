# Building Resonance in Xcode

## 步驟一：產生 Xcode 專案

在 Mac Terminal 中，切換到專案目錄後執行：

```bash
# 安裝 XcodeGen（若尚未安裝）
brew install xcodegen

# 切換到專案目錄
cd /path/to/Resonance-

# 產生 .xcodeproj
xcodegen generate
```

這會在根目錄產生 `Resonance.xcodeproj`。

## 步驟二：開啟專案

```bash
open Resonance.xcodeproj
```

## 步驟三：設定 Signing

1. 在 Xcode 左側選 `Resonance` target
2. Signing & Capabilities → 勾選 `Automatically manage signing`
3. Team → 選擇你的 Apple Developer 帳號

## 步驟四：選擇模擬器

在 Xcode 工具列，選擇 `iPhone 16 Pro Max` 模擬器，按 ▶ 執行。

## 步驟五：首次使用

App 啟動後前往 **設定 (Settings)**，輸入 AI API Key（Claude / OpenAI / Gemini），才能使用 AI 功能。

---

## 常見問題

| 錯誤 | 解法 |
|------|------|
| `Cannot find type 'BGProcessingTask'` | 確認 Deployment Target ≥ iOS 13 |
| `Speech recognition not available` | 在模擬器上 Speech 可能不支援，請用真機測試 |
| `AVAudioSession error` | 模擬器麥克風支援有限，建議真機錄音 |
| Signing 錯誤 | Xcode → Preferences → Accounts 登入 Apple ID |
