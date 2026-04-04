import SwiftUI

struct VoiceNoteRowView: View {
    let note: VoiceNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let cat = note.category {
                    Label(cat.name, systemImage: cat.systemIconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: cat.colorHex) ?? .accentColor)
                } else {
                    Label("未分類", systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(note.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(note.displayText)
                .font(.body)
                .lineLimit(3)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                Label(note.formattedDuration, systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if note.isProcessed {
                    Label("已收入文章", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
