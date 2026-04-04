import SwiftUI

@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var libraryPath = NavigationPath()
    var presentedSheet: Sheet?

    enum Sheet: Identifiable {
        case recording
        case aggregation
        case publish(Article)

        var id: String {
            switch self {
            case .recording:     return "recording"
            case .aggregation:   return "aggregation"
            case .publish(let a): return "publish-\(a.id)"
            }
        }
    }

    func navigateTo(_ destination: NavigationDestination) {
        selectedTab = .library
        libraryPath.append(destination)
    }

    func presentRecording() {
        presentedSheet = .recording
    }

    func presentAggregation() {
        presentedSheet = .aggregation
    }

    func dismissSheet() {
        presentedSheet = nil
    }
}
