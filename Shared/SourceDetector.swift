import Foundation
import LinkPresentation

enum SourceDetector {
    private static let known: [(host: String, name: String)] = [
        ("instagram.com", "Instagram"), ("tiktok.com", "TikTok"),
        ("youtube.com", "YouTube"), ("youtu.be", "YouTube"),
        ("x.com", "X"), ("twitter.com", "X"), ("threads.net", "Threads"),
        ("linkedin.com", "LinkedIn"), ("facebook.com", "Facebook"), ("fb.watch", "Facebook"),
        ("reddit.com", "Reddit"), ("pinterest.com", "Pinterest"), ("medium.com", "Medium"),
    ]

    static func name(for url: URL) -> String {
        let host = (url.host() ?? "").lowercased()
        if let match = known.first(where: { host == $0.host || host.hasSuffix("." + $0.host) }) {
            return match.name
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    /// Estrae il primo link da un testo libero (utile quando l'app di origine condivide solo testo).
    static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, range: range)?.url
    }
}

/// Recupera il titolo di una pagina condivisa. Best effort: molti social nascondono
/// i metadati dietro il login, in quel caso resta solo il link.
@MainActor
enum LinkEnricher {
    static func enrich(_ idea: Idea) async {
        guard idea.sourceTitle == nil,
              let raw = idea.sourceURL, let url = URL(string: raw) else { return }
        let provider = LPMetadataProvider()
        provider.timeout = 8
        guard let meta = try? await provider.startFetchingMetadata(for: url),
              let title = meta.title, !title.isEmpty,
              title.lowercased() != "instagram" else { return }
        idea.sourceTitle = title
        if idea.title.isEmpty { idea.title = title }
    }
}
