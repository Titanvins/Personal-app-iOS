import SwiftUI
import SwiftData

@main
struct IdeaBoxApp: App {
    private let container = Persistence.makeContainer()

    var body: some Scene {
        WindowGroup {
            IdeaListView()
        }
        .modelContainer(container)
    }
}
