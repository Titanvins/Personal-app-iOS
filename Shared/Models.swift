import Foundation
import SwiftData

@Model
final class Idea {
    var id: UUID = UUID()
    var title: String = ""
    var text: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var isPinned: Bool = false
    var tags: [String] = []

    /// Valorizzati quando l'idea nasce da una condivisione (Instagram, TikTok, web...).
    var sourceURL: String?
    var sourceName: String?
    var sourceTitle: String?

    @Relationship(deleteRule: .cascade, inverse: \VoiceNote.idea)
    var voiceNotes: [VoiceNote]?   // CloudKit richiede relazioni opzionali

    init(title: String = "", text: String = "") {
        self.title = title
        self.text = text
    }

    var notes: [VoiceNote] { voiceNotes ?? [] }

    var displayTitle: String {
        if !title.isEmpty { return title }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return firstLine.isEmpty ? "Senza titolo" : firstLine
    }

    var isEmpty: Bool {
        title.isEmpty && text.isEmpty && notes.isEmpty && sourceURL == nil
    }

    var searchableText: String {
        ([title, text, sourceName ?? "", sourceTitle ?? ""] + tags + notes.compactMap(\.transcript))
            .joined(separator: " ")
    }
}

@Model
final class VoiceNote {
    var id: UUID = UUID()
    /// Nome file relativo a `AppGroup.audioDirectory`.
    var fileName: String = ""
    var duration: TimeInterval = 0
    var createdAt: Date = Date.now
    var transcript: String?
    /// L'audio vive nel database (asset CloudKit) così si sincronizza; il file su disco è solo una cache.
    @Attribute(.externalStorage) var audioData: Data?
    var idea: Idea?

    init(fileName: String, duration: TimeInterval) {
        self.fileName = fileName
        self.duration = duration
    }

    var fileURL: URL { AppGroup.audioDirectory.appending(path: fileName) }

    /// File riproducibile: se manca (nota arrivata da un altro dispositivo) lo ricrea dai dati.
    var url: URL {
        let u = fileURL
        if !FileManager.default.fileExists(atPath: u.path), let audioData {
            try? audioData.write(to: u)
        }
        return u
    }
}
