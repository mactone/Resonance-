import SwiftUI

struct ArticleCardView: View {
    let article: Article
    var showProgress: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let cat = article.category {
                    Label(cat.name, systemImage: cat.systemIconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: cat.colorHex) ?? .accentColor)
                }
                Spacer()
                Text(article.generatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(article.title)
                .font(.headline)
                .lineLimit(2)

            Text(article.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 12) {
                Label("\(article.estimatedReadingMinutes) 分鐘", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(article.sourceNotes.count) 筆記", systemImage: "mic")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if article.publishStatus == .published {
                    Label("已發佈", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            if showProgress, article.playbackPositionSeconds > 0 {
                let progress = min(1.0, article.playbackPositionSeconds / Double(max(1, article.segments.count)))
                ProgressView(value: progress)
                    .tint(.accentColor)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
