import SwiftUI

// MARK: - ArticleCardView

#Preview("Article Card — with progress") {
    let ctx = PreviewContainer.makeContext()
    let articles = try! ctx.fetch(.init(Article.self))
    return VStack(spacing: 12) {
        ForEach(articles) { article in
            ArticleCardView(article: article, showProgress: true)
        }
    }
    .padding()
    .modelContainer(PreviewContainer.container)
}

// MARK: - VoiceNoteRowView

#Preview("Voice Note Row") {
    let ctx = PreviewContainer.makeContext()
    let notes = try! ctx.fetch(.init(VoiceNote.self))
    return VStack(spacing: 8) {
        ForEach(notes) { note in
            VoiceNoteRowView(note: note)
        }
    }
    .padding()
    .modelContainer(PreviewContainer.container)
}

// MARK: - CategoryFilterView

#Preview("Category Filter") {
    let ctx = PreviewContainer.makeContext()
    let cats = try! ctx.fetch(.init(NoteCategory.self))
    return CategoryFilterView(categories: cats, selectedCategory: .constant(nil))
        .padding(.vertical)
        .modelContainer(PreviewContainer.container)
}

// MARK: - QuickCaptureButton

#Preview("Quick Capture Button") {
    ZStack {
        Color(.systemBackground)
        QuickCaptureButton {}
    }
}

// MARK: - PlaybackProgressView

#Preview("Playback Progress") {
    VStack(spacing: 20) {
        PlaybackProgressView(currentSegment: 0, totalSegments: 5, segmentProgress: 0.3, onSeek: { _ in })
        PlaybackProgressView(currentSegment: 2, totalSegments: 5, segmentProgress: 0.7, onSeek: { _ in })
        PlaybackProgressView(currentSegment: 4, totalSegments: 5, segmentProgress: 1.0, onSeek: { _ in })
    }
    .padding()
}

// MARK: - Settings

#Preview("Settings") {
    SettingsView()
        .modelContainer(PreviewContainer.container)
}

// MARK: - Aggregation

#Preview("Aggregation") {
    let _ = PreviewContainer.makeContext()
    return AggregationView()
        .environment(AppRouter())
        .modelContainer(PreviewContainer.container)
}

// MARK: - Full App

#Preview("Full App") {
    let _ = PreviewContainer.makeContext()
    return ContentView()
        .environment(AppRouter())
        .modelContainer(PreviewContainer.container)
}
