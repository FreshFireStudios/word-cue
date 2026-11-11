// UNTESTED: written without Xcode. Expect fixes on the first build.
//
// The conductor. Audio -> speech-to-text -> detection engine -> Likely Match
// -> (operator approves, or Auto-send) -> presentation app.
// Behaviour follows the User Guide, sections 04 to 07.
import SwiftUI
import Observation
import AVFoundation
import WordCueKit

@MainActor
@Observable
final class AppModel {
    enum Status: Equatable { case ready, preparing, listening, paused, noAudio }
    enum Problem: Equatable {
        case appLost(String)        // presentation app not reachable; keep listening
        case noAudio
        case other(String)
    }

    // What the screens show
    var status: Status = .ready
    var problem: Problem?
    var waiting: CueItem?                   // the Likely Match
    var history: [CueItem] = []             // This Service, newest first
    var onScreenID: CueItem.ID?
    var transcript: [String] = []
    var volatileText = ""
    var level: Float = 0
    var speechDetected = false
    var musicPlaying = false
    var appConnected: Bool?                 // nil = not checked yet
    var connectionNote = ""
    var notice: String?                     // short confirmation, e.g. "6 verses added."
    var canUndoDrop = false
    var now = Date()                        // ticks once a second so "Heard 4 seconds ago" stays fresh
    var inputDevices: [AudioDevice] = []
    var permissions = SystemIntegration.Permissions()
    var showSetup = false
    var practiceProgress: String?

    let settings = AppSettings()
    let engine = Engine()
    var s: WordCueSettings { settings.s }

    @ObservationIgnored private var session: DetectionSession
    @ObservationIgnored private let audio = AudioInput()
    @ObservationIgnored private let transcriber = LiveTranscriber()
    @ObservationIgnored private let music = MusicDetector()
    @ObservationIgnored private let router = OutputRouter()
    @ObservationIgnored private let hotKeys = GlobalHotKeys()
    @ObservationIgnored private let watcher = AppWatcher()
    @ObservationIgnored private let log = ServiceLog()
    @ObservationIgnored private var record = ServiceRecord()
    @ObservationIgnored private var lastCued: [String: Date] = [:]      // duplicate cooldown
    @ObservationIgnored private var provisionalIDs: Set<Int> = []
    @ObservationIgnored private var lastDrop: [CueItem.ID] = []
    @ObservationIgnored private var lastSound = Date()                  // last time audio rose above the gate
    @ObservationIgnored private var lastSignal = Date()                 // last time any signal arrived at all
    @ObservationIgnored private var sentAt: Date?
    @ObservationIgnored private var lastConnectionCheck = Date.distantPast
    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// Set by the window code so the model can ask for show/hide and compact changes.
    @ObservationIgnored var windowActions: (show: () -> Void, hide: () -> Void, toggle: () -> Void) = ({}, {}, {})

    var isListening: Bool { status == .listening || status == .preparing || status == .noAudio }
    var lastSent: CueItem? { history.first { $0.outcome == .sent || $0.outcome == .autoSent } }
    var bookName: (String) -> String { { [engine] id in engine.book(id).map { $0.singular ?? $0.name } ?? id } }

    init() {
        session = DetectionSession(engine: engine)
        inputDevices = AudioInput.inputDevices()
        KJVStore.shared.preload()
        showSetup = !settings.s.finishedSetup
        settings.onChange = { [weak self] in self?.applySettings() }
        applySettings()
        watcher.onLaunch = { [weak self] in self?.presentationAppOpened() }
        watcher.onQuit = { [weak self] in self?.presentationAppQuit() }
        watcher.onActivate = { [weak self] in
            guard let self, self.s.pairWithApp else { return }
            self.windowActions.show()
        }
        Updater.shared.isServiceRunning = { [weak self] in self?.isListening ?? false }
        log.pruneTranscripts(keepDays: s.keepTranscriptsDays, currentService: record.id)
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
        Task {
            permissions = await SystemIntegration.permissions()
            await checkConnection()
            if s.openAppWithWordCue && !watcher.isRunning { watcher.launchApp() }
            if s.finishedSetup && s.startListening == .whenAppOpens && watcher.isRunning { startListening() }
        }
    }

    // MARK: - Settings

    /// Called whenever a setting changes, and once at launch.
    func applySettings() {
        engine.ignoredBooks = Set(s.ignoredBooks)
        engine.setIgnoredPhrases(s.ignoredPhrases)
        session.quotes = s.recognizeQuotedScripture
        DebugLog.enabled = s.debugLogging
        watcher.watch(s.presentationApp)
        SystemIntegration.setLaunchAtLogin(s.launchAtLogin)
        if s.anywhereShortcuts {
            var keys: [String: KeyCombo] = [:]
            for action in ["send", "skip", "pause", "clear", "resend"] {
                if let combo = KeyCombo(s.shortcuts[action] ?? "") { keys[action] = combo.anywhere }
            }
            keys["showHide"] = KeyCombo("opt+cmd+w")
            hotKeys.register(keys) { [weak self] action in self?.perform(action) }
        } else {
            hotKeys.unregister()
        }
    }

    /// Runs a named action; used by both in-app and Anywhere shortcuts.
    func perform(_ action: String) {
        switch action {
        case "send": sendWaiting()
        case "skip": skipWaiting()
        case "pause": togglePause()
        case "clear": clearScreen()
        case "resend": resendLast()
        case "compact": settings.s.compact.toggle()
        case "undo": undoDrop()
        case "showHide": windowActions.toggle()
        default: break
        }
    }

    // MARK: - Listening

    func togglePause() {
        switch status {
        case .ready, .paused: startListening()
        default: pause()
        }
    }

    func startListening() {
        guard !isListening, s.liveListening else { return }
        let resuming = status == .paused
        status = .preparing
        problem = nil
        if !resuming {
            session = DetectionSession(engine: engine)
            session.quotes = s.recognizeQuotedScripture
        }
        provisionalIDs = []
        lastSound = Date()
        lastSignal = Date()
        if s.keepMacAwake { SystemIntegration.keepAwake(true) }
        var options = AudioInput.Options()
        options.deviceUID = s.inputDeviceUID
        options.channel = s.inputChannel
        options.gainDB = s.inputGainDB
        options.gateDB = s.noiseGateDB
        options.bufferFrames = s.bufferSize.frames
        let vocabulary = engine.vocabulary + s.customVocabulary
        let locale = Locale(identifier: s.language)
        let watchMusic = s.pauseDuringMusic
        Task {
            do {
                try await transcriber.start(locale: locale, vocabulary: vocabulary) { [weak self] update in
                    Task { @MainActor in self?.handle(update) }
                }
                let transcriber = self.transcriber
                let music = self.music
                var musicStarted = false
                music.onChange = { [weak self] playing in Task { @MainActor in self?.musicPlaying = playing } }
                try await audio.start(options) { [weak self] buffer, level, open in
                    if watchMusic {
                        if !musicStarted {
                            music.start(format: buffer.format)
                            musicStarted = true
                        }
                        music.append(buffer)
                    }
                    transcriber.append(buffer)
                    Task { @MainActor in self?.heard(level: level, open: open) }
                }
                status = .listening
                DebugLog.write("Listening started")
            } catch {
                audio.stop()
                await transcriber.stop()
                status = .ready
                problem = .other(error.localizedDescription)
                SystemIntegration.keepAwake(false)
            }
        }
    }

    func pause() {
        guard isListening else { return }
        audio.stop()
        music.stop()
        level = 0
        speechDetected = false
        musicPlaying = false
        volatileText = ""
        status = .paused
        if problem == .noAudio { problem = nil }
        SystemIntegration.keepAwake(false)
        Task { await transcriber.stop() }
        saveLog()
    }

    private func heard(level: Float, open: Bool) {
        self.level = level
        speechDetected = open
        if open { lastSound = Date() }
        if level > 0.02 { lastSignal = Date() }
    }

    // MARK: - Once a second

    private func tick() {
        now = Date()
        // A verse nobody sent goes to the history after a while.
        if let w = waiting, !w.provisional, s.dismissUnsentAfterSeconds > 0,
           now.timeIntervalSince(w.time) > Double(s.dismissUnsentAfterSeconds) {
            finish(w, as: .expired)
        }
        if let sent = sentAt, s.clearScreenAfterMinutes > 0, onScreenID != nil,
           now.timeIntervalSince(sent) > Double(s.clearScreenAfterMinutes) * 60 {
            clearScreen()
        }
        if status == .listening || status == .noAudio {
            let dead = now.timeIntervalSince(lastSignal) > 10          // nothing at all from the interface
            if dead && status != .noAudio {
                status = .noAudio
                problem = .noAudio
                alertIfHidden("No audio", "Word Cue is not receiving sound from the soundboard.")
            } else if !dead && status == .noAudio {
                status = .listening
                if problem == .noAudio { problem = nil }
            }
            if s.autoPauseAfterSilenceMinutes > 0,
               now.timeIntervalSince(lastSound) > Double(s.autoPauseAfterSilenceMinutes) * 60 {
                pause()
            }
        }
        if now.timeIntervalSince(lastConnectionCheck) > 10, s.reconnectAutomatically || appConnected == nil {
            Task { await checkConnection() }
        }
    }

    private func alertIfHidden(_ title: String, _ body: String) {
        if !NSApp.isActive { SystemIntegration.notify(title, body) }
    }

    // MARK: - Transcript in, Likely Match out

    private func handle(_ update: TranscriptUpdate) {
        guard s.detectionEnabled else { return }
        if musicPlaying && s.pauseDuringMusic { return }      // worship lyrics are not cues
        switch update {
        case .volatile(let text):
            volatileText = text
            guard s.detectionSpeed != .moreAccurate else { return }
            let previews = session.preview(text)
            for d in previews { cue(d, provisional: true) }
            let ids = Set(previews.map(\.id))
            if let w = waiting, w.provisional, let id = w.detectionID, !ids.contains(id) { waiting = nil }
            provisionalIDs = ids
        case .final(let text):
            guard !text.isEmpty else { return }
            volatileText = ""
            transcript.append(text)
            if transcript.count > 400 { transcript.removeFirst(transcript.count - 400) }
            if s.keepTranscriptsDays >= 0 { record.transcript.append(text) }
            var confirmed: Set<Int> = []
            for event in session.feed(text) {
                switch event {
                case .new(let d), .update(let d):
                    cue(d, provisional: false)
                    confirmed.insert(d.id)
                case .remove(let id):
                    if waiting?.detectionID == id { waiting = nil }
                }
            }
            if let w = waiting, w.provisional, let id = w.detectionID, !confirmed.contains(id) { waiting = nil }
            provisionalIDs = []
        }
    }

    /// Turns a detection into the Likely Match, after the filters (User Guide section 07, step 4).
    private func cue(_ detection: Detection, provisional: Bool) {
        var d = detection
        if d.kind == .followOn && !s.recognizeFollowUps { return }
        if !s.recognizeRanges { d.reference.endVerse = nil }
        guard d.confidence >= s.minimumConfidence else {
            DebugLog.write("Dropped \(d.key) at \(d.confidence): under the minimum")
            return
        }
        // Same spot in the transcript as the verse already waiting: refine it.
        if var w = waiting, w.detectionID == d.id {
            if w.reference != d.reference {
                w.reference = d.reference
                w.title = engine.display(d.reference)
                w.verses = versesFor(d.reference)
                w.slide = 0
            }
            w.confidence = d.confidence
            w.heard = d.text
            w.provisional = provisional
            waiting = w
            if !provisional { settled(w) }
            return
        }
        if history.contains(where: { $0.detectionID == d.id }) { return }      // already handled
        // The same verse will not appear again inside the cooldown.
        if let last = lastCued[d.key], now.timeIntervalSince(last) < Double(s.duplicateCooldownSeconds) { return }
        let verses = versesFor(d.reference)
        guard !verses.isEmpty else { return }
        if let old = waiting, !old.provisional { finish(old, as: .expired) }      // a newer verse takes its place
        var item = CueItem(detectionID: d.id, reference: d.reference, title: engine.display(d.reference), verses: verses,
                           confidence: d.confidence, heard: d.text, source: d.kind == .quote ? .quote : .live)
        item.provisional = provisional
        waiting = item
        if !provisional { settled(item) }
    }

    /// The recogniser has settled on this verse: start the cooldown, then auto-send or alert.
    private func settled(_ item: CueItem) {
        lastCued[item.reference.key] = now
        DebugLog.write("Likely Match \(item.reference.key) \(item.confidence) heard: \(item.heard)")
        if s.cueMode == .autoSend, item.reference.verse != nil, item.confidence >= s.autoSendAt {
            send(item, auto: true)
        } else {
            if s.soundWhenWaiting { SystemIntegration.playWaitingSound() }
        }
    }

    private func versesFor(_ ref: Reference) -> [Verse] {
        var r = ref
        if s.surroundingVerses > 0, let v = r.verse {
            r.verse = max(1, v - s.surroundingVerses)
            r.endVerse = (ref.endVerse ?? v) + s.surroundingVerses
            let padded = KJVStore.shared.verses(for: r)
            if !padded.isEmpty { return padded }
        }
        return KJVStore.shared.verses(for: ref)
    }

    // MARK: - Operator actions

    func sendWaiting() {
        guard let w = waiting, !w.provisional, problemBlocksSending == false else { return }
        send(w, auto: false)
    }

    /// Send and Skip are dimmed while the presentation app is unreachable.
    var problemBlocksSending: Bool {
        if case .appLost = problem { return true }
        return false
    }

    func skipWaiting() {
        guard let w = waiting else { return }
        finish(w, as: .skipped)
    }

    private func finish(_ item: CueItem, as outcome: LogEntry.Outcome) {
        var done = item
        done.outcome = outcome
        if waiting?.id == item.id { waiting = nil }
        history.removeAll { $0.id == item.id }
        history.insert(done, at: 0)
        saveLog()
    }

    private func send(_ item: CueItem, auto: Bool) {
        guard let verse = item.verseItem(perSlide: s.versesPerSlide, bookName: bookName(item.reference.book),
                                         translation: s.showAbbreviation ? s.translation : "") else { return }
        finish(item, as: auto ? .autoSent : .sent)
        onScreenID = item.id
        sentAt = Date()
        let settings = s
        Task {
            switch await router.send(verse, settings: settings) {
            case .sent(let how):
                appConnected = true
                if case .appLost = problem { problem = nil }
                DebugLog.write("Sent \(verse.title) by \(how)")
            case .failed(let why):
                appConnected = false
                onScreenID = nil
                problem = .appLost(why)
                alertIfHidden("\(settings.presentationApp.displayName) lost connection", "The verse stays in This Service and can be resent.")
                DebugLog.write("Send failed: \(why)")
            }
        }
    }

    func resendLast() {
        if let last = lastSent { resend(last.id) }
    }

    func resend(_ id: CueItem.ID) {
        guard let item = history.first(where: { $0.id == id }) else { return }
        send(item, auto: false)
    }

    /// Pages through a longer passage one slide at a time.
    func stepSlide(_ step: Int) {
        if var w = waiting {
            let next = w.slide + step
            if w.slides(perSlide: s.versesPerSlide).indices.contains(next) {
                w.slide = next
                waiting = w
            }
        } else if let i = history.firstIndex(where: { $0.id == onScreenID }) {
            let next = history[i].slide + step
            if history[i].slides(perSlide: s.versesPerSlide).indices.contains(next) {
                history[i].slide = next
                resend(history[i].id)
            }
        }
    }

    func clearScreen() {
        onScreenID = nil
        sentAt = nil
        let settings = s
        Task { _ = await router.clear(settings: settings) }
    }

    /// The operator says Word Cue got this one wrong. Corrections (never audio)
    /// are what a church can share to improve detection.
    func markWrong(_ id: CueItem.ID, correctKey: String = "") {
        guard let i = history.firstIndex(where: { $0.id == id }) else { return }
        history[i].correctedKey = correctKey
        saveLog()
    }

    // MARK: - Presentation app

    func checkConnection() async {
        lastConnectionCheck = Date()
        switch await router.test(settings: s) {
        case .success(let note):
            appConnected = true
            connectionNote = note
            if case .appLost = problem { problem = nil }
        case .failure(let error):
            let was = appConnected
            appConnected = false
            connectionNote = error.localizedDescription
            if was == true, isListening { problem = .appLost(error.localizedDescription) }
        }
    }

    func reconnect() {
        Task { await checkConnection() }
    }

    private func presentationAppOpened() {
        if s.showWhenAppOpens { windowActions.show() }
        if s.finishedSetup && s.startListening == .whenAppOpens { startListening() }
        Task {
            try? await Task.sleep(for: .seconds(3))      // give its API a moment to start
            await checkConnection()
        }
    }

    private func presentationAppQuit() {
        appConnected = false
        if s.whenAppQuits == .quit {
            saveLog()
            NSApp.terminate(nil)
        } else {
            windowActions.hide()
        }
    }

    // MARK: - Dropped files (User Guide section 06)

    func importFiles(_ urls: [URL]) {
        Task {
            var added: [CueItem] = []
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let found = try? await FileImporter.detections(in: url, engine: engine) else { continue }
                for d in found {
                    let verses = KJVStore.shared.verses(for: d.reference)
                    guard !verses.isEmpty else { continue }
                    var item = CueItem(detectionID: nil, reference: d.reference, title: engine.display(d.reference), verses: verses,
                                       confidence: d.confidence, heard: url.lastPathComponent, source: .file)
                    item.outcome = .added
                    added.append(item)
                }
            }
            guard !added.isEmpty else {
                notice = "No Bible references were found in that file."
                return
            }
            // Try the presentation app's own service list first; either way the verses are in This Service.
            var inApp = 0
            for item in added {
                if let verse = item.verseItem(perSlide: 0, bookName: bookName(item.reference.book), translation: s.translation),
                   case .sent = await router.addToServiceList(verse, settings: s) { inApp += 1 }
            }
            history.insert(contentsOf: added.reversed(), at: 0)      // first reference in the file ends up on top
            lastDrop = added.map(\.id)
            canUndoDrop = true
            let n = added.count
            notice = "\(n) verse\(n == 1 ? "" : "s") added" + (inApp == n ? " to \(s.presentationApp.displayName)." : " to This Service.")
            saveLog()
        }
    }

    /// Takes the dropped verses back out of Word Cue. Verses already added to
    /// the presentation app's own list have to be removed there.
    func undoDrop() {
        guard canUndoDrop else { return }
        history.removeAll { lastDrop.contains($0.id) }
        lastDrop = []
        canUndoDrop = false
        notice = "File drop undone."
        saveLog()
    }

    // MARK: - Practice session (Settings > General)

    /// Runs a recorded sermon through the same pipeline so a church can see
    /// what Word Cue catches before the first Sunday. Nothing is sent to the screen.
    func runPractice(_ url: URL) {
        guard !isListening else { return }
        practiceProgress = "Reading the recording…"
        let practice = DetectionSession(engine: engine)
        practice.quotes = s.recognizeQuotedScripture
        let vocabulary = engine.vocabulary + s.customVocabulary
        Task {
            var found = 0
            do {
                try await transcriber.transcribe(file: url, locale: Locale(identifier: s.language), vocabulary: vocabulary) { [weak self] update in
                    guard case .final(let text) = update else { return }
                    Task { @MainActor in
                        guard let self else { return }
                        self.transcript.append(text)
                        for event in practice.feed(text) {
                            guard case .new(let d) = event, d.confidence >= self.s.minimumConfidence else { continue }
                            let verses = KJVStore.shared.verses(for: d.reference)
                            guard !verses.isEmpty else { continue }
                            var item = CueItem(detectionID: nil, reference: d.reference, title: self.engine.display(d.reference),
                                               verses: verses, confidence: d.confidence, heard: d.text, source: .live)
                            item.outcome = .skipped
                            self.history.insert(item, at: 0)
                            found += 1
                            self.practiceProgress = "Practice: \(found) verses caught so far…"
                        }
                    }
                }
                practiceProgress = "Practice finished: \(found) verses caught. They are listed in This Service."
            } catch {
                practiceProgress = "Practice could not run: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Service log

    private func saveLog() {
        record.entries = history.reversed().map(\.logEntry)
        log.save(record, keepTranscriptDays: s.keepTranscriptsDays)
    }

    func exportServiceLog() -> String { ServiceLog.exportText(record) }
    var pastServices: [ServiceRecord] { log.all() }
    var logFolder: URL { log.folder }

    func newService() {
        saveLog()
        record = ServiceRecord()
        history = []
        waiting = nil
        transcript = []
        lastCued = [:]
        onScreenID = nil
        log.pruneTranscripts(keepDays: s.keepTranscriptsDays, currentService: record.id)
    }

    func refreshDevices() { inputDevices = AudioInput.inputDevices() }
    func refreshPermissions() { Task { permissions = await SystemIntegration.permissions() } }

    func quitConfirmed() {
        saveLog()
        NSApp.terminate(nil)
    }
}
