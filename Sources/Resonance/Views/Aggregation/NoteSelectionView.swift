import SwiftUI

struct NoteSelectionView: View {
    let notes: [VoiceNote]
    @Binding var selectedIDs: Set<UUID>

    var body: some View {
        List(notes) { note in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectedIDs.contains(note.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedIDs.contains(note.id) ? .accentColor : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    if let cat = note.category {
                        Label(cat.name, systemImage: cat.systemIconName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(hex: cat.colorHex) ?? .accentColor)
                    }
                    Text(note.displayText)
                        .font(.subheadline)
                        .lineLimit(2)
                    Text(note.recordedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selectedIDs.contains(note.id) {
                    selectedIDs.remove(note.id)
                } else {
                    selectedIDs.insert(note.id)
                }
            }
            .listRowBackground(
                selectedIDs.contains(note.id)
                    ? Color.accentColor.opacity(0.08)
                    : Color.clear
            )
        }
        .listStyle(.plain)
    }
}
