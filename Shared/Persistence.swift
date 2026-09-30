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
    static let cloudContainerID = "iCloud.com.vincenzo.ideabox"

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Idea.self, VoiceNote.self])
        let storeURL = AppGroup.containerURL.appending(path: "IdeaBox.store")
        // Prima prova con iCloud; se non disponibile (es. build non firmata) resta locale.
        for db in [ModelConfiguration.CloudKitDatabase.private(cloudContainerID), .none] {
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: db)
            if let container = try? ModelContainer(for: schema, configurations: config) { return container }
        }
        fatalError("Impossibile aprire il database")
    }

    static func delete(_ idea: Idea, in context: ModelContext) {
        for note in idea.notes {
            try? FileManager.default.removeItem(at: note.fileURL)
        }
        context.delete(idea)
        try? context.save()
    }
}
