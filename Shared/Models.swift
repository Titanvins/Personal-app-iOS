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
    var voiceNotes: [VoiceNote] = []

    init(title: String = "", text: String = "") {
        self.title = title
        self.text = text
    }

    var displayTitle: String {
        if !title.isEmpty { return title }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return firstLine.isEmpty ? "Senza titolo" : firstLine
    }

    var isEmpty: Bool {
        title.isEmpty && text.isEmpty && voiceNotes.isEmpty && sourceURL == nil
    }

    var searchableText: String {
        ([title, text, sourceName ?? "", sourceTitle ?? ""] + tags + voiceNotes.compactMap(\.transcript))
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
    var idea: Idea?

    init(fileName: String, duration: TimeInterval) {
        self.fileName = fileName
        self.duration = duration
    }

    var url: URL { AppGroup.audioDirectory.appending(path: fileName) }
}
