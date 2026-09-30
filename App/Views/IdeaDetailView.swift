import SwiftUI
import SwiftData

struct IdeaDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var idea: Idea

    @State private var player = AudioPlayer()
    @State private var tagsText = ""
    @State private var showRecorder = false

    var body: some View {
        Form {
            Section {
                TextField("Titolo", text: $idea.title)
                TextEditor(text: $idea.text)
                    .frame(minHeight: 140)
            }

            if let raw = idea.sourceURL, let url = URL(string: raw) {
                Section("Fonte") {
                    Link(destination: url) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(idea.sourceName ?? "Link", systemImage: "arrow.up.right.square")
                            if let t = idea.sourceTitle {
                                Text(t).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Text(raw).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        }
                    }
                }
            }

            Section("Note vocali") {
                ForEach(idea.voiceNotes.sorted { $0.createdAt < $1.createdAt }) { note in
                    VoiceNoteRow(note: note, idea: idea, player: player)
                }
                .onDelete { offsets in
                    let sorted = idea.voiceNotes.sorted { $0.createdAt < $1.createdAt }
                    for i in offsets {
                        try? FileManager.default.removeItem(at: sorted[i].url)
                        context.delete(sorted[i])
                    }
                }
                Button("Aggiungi nota vocale", systemImage: "mic.badge.plus") { showRecorder = true }
            }

            Section("Tag") {
                TextField("es. business, app, video", text: $tagsText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Button(idea.isPinned ? "Rimuovi dai preferiti" : "Aggiungi ai preferiti",
                       systemImage: idea.isPinned ? "star.slash" : "star") {
                    idea.isPinned.toggle()
                }
                Button("Elimina idea", systemImage: "trash", role: .destructive) {
                    let target = idea
                    dismiss()
                    Persistence.delete(target, in: context)
                }
            }
        }
        .navigationTitle(idea.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRecorder) { RecorderSheet(idea: idea) }
        .onAppear { tagsText = idea.tags.joined(separator: ", ") }
        .onChange(of: tagsText) { _, value in
            idea.tags = value
                .split(whereSeparator: { ",;".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "") }
                .filter { !$0.isEmpty }
        }
        .onDisappear {
            player.stop()
            guard !idea.isDeleted, idea.modelContext != nil else { return }
            if idea.isEmpty {
                context.delete(idea)   // bozza vuota: non lasciarla in lista
            } else {
                idea.updatedAt = .now
            }
        }
    }
}

private struct VoiceNoteRow: View {
    let note: VoiceNote
    let idea: Idea
    let player: AudioPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    player.toggle(note)
                } label: {
                    Image(systemName: player.playingID == note.id ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading) {
                    Text(note.createdAt, format: .dateTime.day().month().hour().minute())
                    Text(Duration.seconds(note.duration), format: .time(pattern: .minuteSecond))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let t = note.transcript {
                Text(t).font(.callout).foregroundStyle(.secondary)
                if !idea.text.contains(t) {
                    Button("Inserisci nel testo", systemImage: "text.append") {
                        idea.text += (idea.text.isEmpty ? "" : "\n\n") + t
                    }
                    .font(.caption)
                }
            } else {
                Button("Trascrivi", systemImage: "text.bubble") {
                    Task { await Transcriber.transcribeAndApply(note, to: idea) }
                }
                .font(.caption)
            }
        }
    }
}
