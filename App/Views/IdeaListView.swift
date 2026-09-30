import SwiftUI
import SwiftData

struct IdeaListView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "Tutte", pinned = "Preferite", voice = "Vocali", links = "Link"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]

    @State private var search = ""
    @State private var filter: Filter = .all
    @State private var path: [Idea] = []
    @State private var showRecorder = false

    private var visible: [Idea] {
        let filtered = ideas.filter { idea in
            switch filter {
            case .all: true
            case .pinned: idea.isPinned
            case .voice: !idea.voiceNotes.isEmpty
            case .links: idea.sourceURL != nil
            }
        }.filter {
            search.isEmpty || $0.searchableText.localizedCaseInsensitiveContains(search)
        }
        return filtered.filter(\.isPinned) + filtered.filter { !$0.isPinned }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if visible.isEmpty {
                    ContentUnavailableView(
                        search.isEmpty ? "Nessuna idea" : "Nessun risultato",
                        systemImage: "lightbulb",
                        description: Text(search.isEmpty
                            ? "Scrivi, registra una nota vocale o condividi un post da Instagram."
                            : "Prova con un'altra ricerca.")
                    )
                } else {
                    List {
                        ForEach(visible) { idea in
                            NavigationLink(value: idea) { IdeaRow(idea: idea) }
                                .swipeActions(edge: .leading) {
                                    Button(idea.isPinned ? "Rimuovi" : "Fissa", systemImage: "star") {
                                        idea.isPinned.toggle()
                                    }.tint(.yellow)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Elimina", systemImage: "trash", role: .destructive) {
                                        Persistence.delete(idea, in: context)
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Idee")
            .navigationDestination(for: Idea.self) { IdeaDetailView(idea: $0) }
            .searchable(text: $search, prompt: "Cerca in idee, trascrizioni, tag")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Filtro", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)
                }
            }
            .safeAreaInset(edge: .bottom) { captureBar }
            .sheet(isPresented: $showRecorder) { RecorderSheet(idea: nil) }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                for idea in ideas where idea.sourceURL != nil && idea.sourceTitle == nil {
                    await LinkEnricher.enrich(idea)
                }
            }
        }
    }

    private var captureBar: some View {
        HStack(spacing: 16) {
            Button {
                showRecorder = true
            } label: {
                Label("Nota vocale", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                let idea = Idea()
                context.insert(idea)
                path.append(idea)
            } label: {
                Label("Nuova idea", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct IdeaRow: View {
    let idea: Idea

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if idea.isPinned { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
                Text(idea.displayTitle).font(.headline).lineLimit(1)
            }
            if !idea.text.isEmpty {
                Text(idea.text).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            HStack(spacing: 10) {
                if let name = idea.sourceName { Label(name, systemImage: "link") }
                if !idea.voiceNotes.isEmpty { Label("\(idea.voiceNotes.count)", systemImage: "waveform") }
                ForEach(idea.tags.prefix(3), id: \.self) { Text("#\($0)") }
                Spacer()
                Text(idea.updatedAt, format: .relative(presentation: .named))
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
