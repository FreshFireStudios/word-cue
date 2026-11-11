// UNTESTED: written without Xcode. Expect small fixes on the first build.
//
// The conductor. Audio -> speech-to-text -> detection engine -> suggestion
// cards -> (operator approves) -> ProPresenter.
import SwiftUI
import Observation
import AVFoundation
import WordCueKit

@MainActor
@Observable
final class AppModel {
    enum Status: Equatable {
        case idle
        case preparing
        case listening
        case problem(String)
    }

    // What the screens show
    var suggestions: [Suggestion] = []      // newest first
    var selectedID: Suggestion.ID?
    var transcript: [String] = []           // finalized lines, newest last
    var volatileText = ""                   // words still being worked out
    var status: Status = .idle
    var level: Float = 0                    // input loudness 0...1
    var banner: String?                     // one-line message under the header
    var compact = false
    var showingReport = false
    var inputDevices: [AudioDevice] = []

    let settings = AppSettings()
    let engine = Engine()

    @ObservationIgnored private var session: DetectionSession
    @ObservationIgnored private let audio = AudioInput()
    @ObservationIgnored private let transcriber = LiveTranscriber()
    @ObservationIgnored private let sender: PresentationSender
    @ObservationIgnored private let hotKeys = GlobalHotKeys()
    @ObservationIgnored private var provisionalIDs: Set<Int> = []

    var isListening: Bool { status == .listening || status == .preparing }
    var onScreen: Suggestion? { suggestions.first { $0.state == .onScreen } }
    var visibleSuggestions: [Suggestion] { suggestions.filter { $0.state != .dismissed } }

    init() {
        session = DetectionSession(engine: engine)
        sender = PresentationSender(settings: settings.proPresenter)
        inputDevices = AudioInput.inputDevices()
        KJVStore.shared.preload()
        hotKeys.register { [weak self] action in
            guard let self else { return }
            switch action {
            case .send: self.sendSelected()
            case .dismiss: self.dismissSelected()
            case .up: self.moveSelection(-1)
            case .down: self.moveSelection(1)
            case .nextVerse: self.stepVerse(1)
            case .previousVerse: self.stepVerse(-1)
            case .clear: self.clearScreen()
            }
        }
    }

    // MARK: - Listening

    func toggleListening() {
        if isListening { stopListening() } else { startListening() }
    }

    func startListening() {
        guard !isListening else { return }
        status = .preparing
        banner = nil
        session = DetectionSession(engine: engine)
        provisionalIDs = []
        Task {
            do {
                try await transcriber.start(vocabulary: engine.vocabulary) { [weak self] update in
                    Task { @MainActor in self?.handle(update) }
                }
                let transcriber = self.transcriber
                try await audio.start(deviceUID: settings.inputDeviceUID) { [weak self] buffer in
                    transcriber.append(buffer)
                    let level = AudioInput.level(of: buffer)
                    Task { @MainActor in self?.level = level }
                }
                status = .listening
            } catch {
                audio.stop()
                await transcriber.stop()
                status = .problem(error.localizedDescription)
            }
        }
    }

    func stopListening() {
        audio.stop()
        level = 0
        volatileText = ""
        status = .idle
        Task { await transcriber.stop() }
    }

    // MARK: - Transcript in, suggestions out

    private func handle(_ update: TranscriptUpdate) {
        switch update {
        case .volatile(let text):
            volatileText = text
            // Search the not-yet-final words too. This is where the speed comes from.
            let previews = session.preview(text)
            let ids = Set(previews.map(\.id))
            for d in previews { upsert(d, provisional: true) }
            for gone in provisionalIDs.subtracting(ids) { removeProvisional(gone) }
            provisionalIDs = ids
        case .final(let text):
            guard !text.isEmpty else { return }
            volatileText = ""
            transcript.append(text)
            if transcript.count > 200 { transcript.removeFirst(transcript.count - 200) }
            let events = session.feed(text)
            var confirmed: Set<Int> = []
            for event in events {
                switch event {
                case .new(let d), .update(let d):
                    upsert(d, provisional: false)
                    confirmed.insert(d.id)
                case .remove(let id):
                    removeProvisional(id, evenIfPending: true)
                }
            }
            for gone in provisionalIDs.subtracting(confirmed) {
                // a guess that did not survive: drop it unless the final text confirmed it earlier
                if let i = suggestions.firstIndex(where: { $0.detectionID == gone }), suggestions[i].state == .provisional {
                    suggestions.remove(at: i)
                }
            }
            provisionalIDs = []
        }
    }

    private func upsert(_ d: Detection, provisional: Bool) {
        guard d.confidence >= settings.minimumConfidence else { return }
        let verses = KJVStore.shared.verses(for: d.reference)
        guard !verses.isEmpty else { return }
        if let i = suggestions.firstIndex(where: { $0.detectionID == d.id }) {
            // Never change a card the operator already acted on.
            guard suggestions[i].state == .provisional || suggestions[i].state == .pending else { return }
            if suggestions[i].reference != d.reference {
                suggestions[i].reference = d.reference
                suggestions[i].title = engine.display(d.reference)
                suggestions[i].verses = verses
                suggestions[i].verseIndex = 0
            }
            suggestions[i].confidence = d.confidence
            suggestions[i].heard = d.text
            suggestions[i].flags = d.flags
            if !provisional { suggestions[i].state = .pending }
        } else {
            var s = Suggestion(detectionID: d.id, reference: d.reference, title: engine.display(d.reference),
                               verses: verses, confidence: d.confidence, heard: d.text, flags: d.flags)
            s.state = provisional ? .provisional : .pending
            suggestions.insert(s, at: 0)
            if selectedID == nil || onScreen == nil { selectedID = s.id }
        }
        // Auto-send is off unless the church turns it on, and only for settled, verse-level matches.
        if !provisional, settings.autoSend, d.reference.verse != nil, d.confidence >= settings.autoSendThreshold,
           let s = suggestions.first(where: { $0.detectionID == d.id }), s.state == .pending {
            send(s.id)
        }
    }

    private func removeProvisional(_ detectionID: Int, evenIfPending: Bool = false) {
        guard let i = suggestions.firstIndex(where: { $0.detectionID == detectionID }) else { return }
        let state = suggestions[i].state
        if state == .provisional || (evenIfPending && state == .pending) {
            let wasSelected = suggestions[i].id == selectedID
            suggestions.remove(at: i)
            if wasSelected { selectedID = visibleSuggestions.first?.id }
        }
    }

    // MARK: - Operator actions

    func sendSelected() {
        if let id = selectedID ?? visibleSuggestions.first?.id { send(id) }
    }

    func send(_ id: Suggestion.ID) {
        guard let i = suggestions.firstIndex(where: { $0.id == id }), let verse = suggestions[i].currentVerse else { return }
        let bookName = engine.book(verse.book).map { $0.singular ?? $0.name } ?? verse.book
        let title = suggestions[i].currentTitle(bookName: bookName)
        for j in suggestions.indices where suggestions[j].state == .onScreen { suggestions[j].state = .sent }
        suggestions[i].state = .onScreen
        selectedID = id
        let onStage = settings.alsoShowOnStage
        Task {
            await sender.update(settings.proPresenter)
            switch await sender.show(verse: verse, title: title, alsoOnStage: onStage) {
            case .shown:
                banner = nil
            case .copied(let why):
                banner = "ProPresenter did not take it (\(why)) \"\(title)\" is copied. Paste it into ProPresenter's Bible search."
            }
        }
    }

    func dismissSelected() {
        guard let id = selectedID, let i = suggestions.firstIndex(where: { $0.id == id }) else { return }
        if suggestions[i].state == .onScreen { clearScreen() }
        suggestions[i].state = .dismissed
        selectedID = visibleSuggestions.first?.id
    }

    func moveSelection(_ step: Int) {
        let list = visibleSuggestions
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == selectedID } ?? 0
        selectedID = list[max(0, min(list.count - 1, current + step))].id
    }

    /// Pages through a range or a chapter one verse at a time.
    func stepVerse(_ step: Int) {
        guard let id = selectedID, let i = suggestions.firstIndex(where: { $0.id == id }) else { return }
        let next = suggestions[i].verseIndex + step
        guard suggestions[i].verses.indices.contains(next) else { return }
        suggestions[i].verseIndex = next
        if suggestions[i].state == .onScreen { send(id) }   // already live: follow along
    }

    func clearScreen() {
        for j in suggestions.indices where suggestions[j].state == .onScreen { suggestions[j].state = .sent }
        Task { await sender.clear() }
    }

    func clearList() {
        suggestions.removeAll { $0.state != .onScreen }
        selectedID = suggestions.first?.id
    }

    // MARK: - Dropped files

    func importFiles(_ urls: [URL]) {
        Task {
            var added = 0
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let found = try? await FileImporter.detections(in: url, engine: engine) else { continue }
                // keep the file's order: first reference ends up on top
                for d in found.reversed() {
                    let verses = KJVStore.shared.verses(for: d.reference)
                    guard !verses.isEmpty else { continue }
                    var s = Suggestion(detectionID: nil, reference: d.reference, title: engine.display(d.reference),
                                       verses: verses, confidence: d.confidence, heard: url.lastPathComponent, flags: d.flags)
                    s.isFromFile = true
                    suggestions.insert(s, at: 0)
                    added += 1
                }
            }
            banner = added == 0 ? "No Bible references were found in that file."
                                : "Added \(added) reference\(added == 1 ? "" : "s") from the file."
            if selectedID == nil { selectedID = suggestions.first?.id }
        }
    }

    // MARK: - Settings helpers

    func refreshDevices() { inputDevices = AudioInput.inputDevices() }

    func testConnection() async -> String {
        await sender.update(settings.proPresenter)
        switch await sender.testConnection() {
        case .success(let message): return message
        case .failure(let error): return error.localizedDescription
        }
    }

    func setUpMessage() async -> String {
        await sender.update(settings.proPresenter)
        switch await sender.setUpMessage() {
        case .success(let message): return message
        case .failure(let error): return error.localizedDescription
        }
    }

    func sendReport(note: String, includeTranscript: Bool) async -> String {
        let report = FeedbackReporter.buildReport(note: note, suggestions: suggestions,
                                                  transcriptTail: Array(transcript.suffix(30)),
                                                  includeTranscript: includeTranscript)
        return await FeedbackReporter.send(report)
    }
}
