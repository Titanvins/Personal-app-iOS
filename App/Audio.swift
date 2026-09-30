import AVFoundation
import Speech
import Observation

@Observable @MainActor
final class AudioRecorder {
    var isRecording = false
    var elapsed: TimeInterval = 0
    var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileName: String?

    func start() async {
        guard await AVAudioApplication.requestRecordPermission() else {
            permissionDenied = true
            return
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let name = "\(UUID().uuidString).m4a"
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            let rec = try AVAudioRecorder(url: AppGroup.audioDirectory.appending(path: name), settings: settings)
            guard rec.record() else { return }
            recorder = rec
            fileName = name
            elapsed = 0
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.elapsed = self?.recorder?.currentTime ?? 0 }
            }
        } catch {
            permissionDenied = false
        }
    }

    /// Ferma la registrazione e restituisce il file prodotto.
    func stop() -> (fileName: String, duration: TimeInterval)? {
        timer?.invalidate()
        timer = nil
        guard let recorder, let fileName else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        self.fileName = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return duration > 0.5 ? (fileName, duration) : nil
    }

    func cancel() {
        let name = fileName
        _ = stop()
        if let name { try? FileManager.default.removeItem(at: AppGroup.audioDirectory.appending(path: name)) }
    }
}

@Observable @MainActor
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    var playingID: UUID?
    private var player: AVAudioPlayer?

    func toggle(_ note: VoiceNote) {
        if playingID == note.id { stop(); return }
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let p = try? AVAudioPlayer(contentsOf: note.url) else { return }
        p.delegate = self
        p.play()
        player = p
        playingID = note.id
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}

enum Transcriber {
    /// Trascrive un file audio in italiano, on-device quando disponibile.
    static func transcribe(url: URL, locale: Locale = Locale(identifier: "it-IT")) async -> String? {
        let status = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard status == .authorized,
              let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else { return nil }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = false

        return await withCheckedContinuation { (c: CheckedContinuation<String?, Never>) in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let result, result.isFinal {
                    finished = true
                    let text = result.bestTranscription.formattedString
                    c.resume(returning: text.isEmpty ? nil : text)
                } else if error != nil {
                    finished = true
                    c.resume(returning: nil)
                }
            }
        }
    }

    /// Trascrive la nota e, se l'idea non ha ancora testo/titolo, li riempie dalla trascrizione.
    @MainActor
    static func transcribeAndApply(_ note: VoiceNote, to idea: Idea) async {
        guard let text = await transcribe(url: note.url) else { return }
        note.transcript = text
        if idea.text.isEmpty { idea.text = text }
        if idea.title.isEmpty {
            idea.title = text.split(separator: " ").prefix(6).joined(separator: " ")
        }
        idea.updatedAt = .now
    }
}
