import Foundation
import SwiftData

/// App e Share Extension condividono database e audio tramite App Group.
enum AppGroup {
    static let id = "group.com.vincenzo.ideabox"

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) ?? URL.documentsDirectory
    }

    static var audioDirectory: URL {
        let dir = containerURL.appending(path: "Audio", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

enum Persistence {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([Idea.self, VoiceNote.self])
        let config = ModelConfiguration(
            schema: schema,
            url: AppGroup.containerURL.appending(path: "IdeaBox.store"),
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Impossibile aprire il database: \(error)")
        }
    }

    static func delete(_ idea: Idea, in context: ModelContext) {
        for note in idea.voiceNotes {
            try? FileManager.default.removeItem(at: note.url)
        }
        context.delete(idea)
        try? context.save()
    }
}
