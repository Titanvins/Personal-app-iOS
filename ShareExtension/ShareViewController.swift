import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Compare nel foglio di condivisione di Instagram, Safari, TikTok, ecc.
final class ShareViewController: UIViewController {
    private let container = Persistence.makeContainer()

    override func viewDidLoad() {
        super.viewDidLoad()
        let root = ShareView(
            items: (extensionContext?.inputItems as? [NSExtensionItem]) ?? [],
            container: container,
            onClose: { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) },
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: NSError(domain: "IdeaBox", code: 0))
            }
        )
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

private struct ShareView: View {
    let items: [NSExtensionItem]
    let container: ModelContainer
    let onClose: () -> Void
    let onCancel: () -> Void

    @State private var url: URL?
    @State private var sharedText = ""
    @State private var note = ""
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Form {
                if let url {
                    Section(SourceDetector.name(for: url)) {
                        Text(url.absoluteString).font(.footnote).lineLimit(3)
                    }
                }
                if !sharedText.isEmpty {
                    Section("Testo condiviso") { Text(sharedText).lineLimit(6) }
                }
                Section("La tua nota") {
                    TextField("Perché ti interessa? Che idea ti dà?", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Salva in Idee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva", action: save).disabled(loading || (url == nil && sharedText.isEmpty))
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        for item in items {
            if let attributed = item.attributedContentText?.string, sharedText.isEmpty { sharedText = attributed }
            for provider in item.attachments ?? [] {
                if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let value = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) {
                    url = (value as? URL) ?? (value as? String).flatMap(URL.init(string:))
                } else if sharedText.isEmpty, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let value = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) {
                    sharedText = (value as? String) ?? ""
                }
            }
        }
        // Alcune app condividono solo testo con il link dentro.
        if url == nil { url = SourceDetector.firstURL(in: sharedText) }
        // Se il testo è solo il link, non mostrarlo due volte.
        if let url, sharedText.trimmingCharacters(in: .whitespacesAndNewlines) == url.absoluteString { sharedText = "" }
        loading = false
    }

    private func save() {
        let context = ModelContext(container)
        let idea = Idea(text: [note, sharedText].filter { !$0.isEmpty }.joined(separator: "\n\n"))
        if let url {
            idea.sourceURL = url.absoluteString
            idea.sourceName = SourceDetector.name(for: url)
        }
        context.insert(idea)
        try? context.save()
        onClose()
    }
}
