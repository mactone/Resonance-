import SwiftUI

enum NavigationDestination: Hashable {
    case articlePlayer(Article)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .articlePlayer(let a): hasher.combine(a.id)
        }
    }

    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.articlePlayer(let a), .articlePlayer(let b)): return a.id == b.id
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .articlePlayer(let article):
            ArticlePlayerView(article: article)
        }
    }
}
