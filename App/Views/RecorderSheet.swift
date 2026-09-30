import SwiftUI
import SwiftData

/// Registra una nota vocale. Con `idea == nil` crea una nuova idea, altrimenti aggiunge alla esistente.
struct RecorderSheet: View {
    let idea: Idea?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = AudioRecorder()

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text(Duration.seconds(recorder.elapsed), format: .time(pattern: .minuteSecond))
                .font(.system(size: 56, weight: .light, design: .monospaced))

            Button {
                if recorder.isRecording { finish() } else { Task { await recorder.start() } }
            } label: {
                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(recorder.isRecording ? Color.red : Color.accentColor))
            }

            Text(recorder.isRecording ? "Tocca per fermare e salvare" : "Tocca per iniziare")
                .foregroundStyle(.secondary)

            if recorder.permissionDenied {
                Text("Consenti l'accesso al microfono da Impostazioni > Idee.")
                    .font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            Spacer()
            Button("Annulla") { recorder.cancel(); dismiss() }
        }
        .padding()
        .presentationDetents([.medium])
        .interactiveDismissDisabled(recorder.isRecording)
        .task { await recorder.start() }   // parte subito: è una cattura rapida
    }

    private func finish() {
        guard let result = recorder.stop() else { dismiss(); return }
        let target = idea ?? Idea()
        if idea == nil { context.insert(target) }
        let note = VoiceNote(fileName: result.fileName, duration: result.duration)
        note.audioData = try? Data(contentsOf: note.fileURL)
        if target.voiceNotes == nil { target.voiceNotes = [] }
        target.voiceNotes?.append(note)
        target.updatedAt = .now
        try? context.save()
        dismiss()
        Task { await Transcriber.transcribeAndApply(note, to: target) }
    }
}
