import SwiftUI

struct TranscriptionPreviewView: View {
    let transcription: String
    let onSave: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("轉錄預覽")
                .font(.headline)

            ScrollView {
                Text(transcription.isEmpty ? "（無法辨識語音）" : transcription)
                    .font(.body)
                    .foregroundStyle(transcription.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button(role: .destructive, action: onDiscard) {
                    Label("丟棄", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onSave) {
                    Label("儲存筆記", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
