import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct ResonanceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VoiceNote.self,
            NoteCategory.self,
            Article.self,
            ArticleSegment.self,
            BlogPlatformConfig.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(AppRouter())
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundGenerationService.shared.registerBackgroundTask()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundGenerationService.shared.scheduleBackgroundGeneration()
    }
}
