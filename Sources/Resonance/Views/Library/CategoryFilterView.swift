import SwiftUI

struct CategoryFilterView: View {
    let categories: [NoteCategory]
    @Binding var selectedCategory: NoteCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: "全部", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(categories) { cat in
                    FilterPill(
                        title: cat.name,
                        icon: cat.systemIconName,
                        isSelected: selectedCategory?.id == cat.id
                    ) {
                        selectedCategory = selectedCategory?.id == cat.id ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterPill: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.caption)
                }
                Text(title).font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
