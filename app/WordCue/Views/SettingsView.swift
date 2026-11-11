// UNTESTED: written without Xcode.
// Settings (User Guide section 08): a sidebar with nine panels in four
// groups, and a search box that finds any setting by name.
// One home per setting: every setting lives in exactly one panel.
import SwiftUI
import UniformTypeIdentifiers
import WordCueKit

enum SettingsPanel: String, CaseIterable, Identifiable {
    case general = "General"
    case audio = "Audio Input"
    case detection = "Scripture Detection"
    case output = "Verse Output"
    case appearance = "Appearance"
    case shortcuts = "Shortcuts & Controls"
    case filters = "Filters"
    case advanced = "Advanced"
    case support = "Support"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "house"
        case .audio: return "waveform"
        case .detection: return "text.magnifyingglass"
        case .output: return "tv"
        case .appearance: return "paintbrush"
        case .shortcuts: return "keyboard"
        case .filters: return "line.3.horizontal.decrease.circle"
        case .advanced: return "wrench.and.screwdriver"
        case .support: return "lifepreserver"
        }
    }

    static let groups: [(String, [SettingsPanel])] = [
        ("Home", [.general]),
        ("Service", [.audio, .detection, .output]),
        ("Customization", [.appearance, .shortcuts, .filters]),
        ("System", [.advanced, .support])
    ]

    /// Every setting's name, for search.
    var settingNames: [String] {
        switch self {
        case .general: return ["Cue mode", "Auto-send at", "Start listening", "Launch at login", "Show menu bar icon", "Keep Mac awake", "Confirm before quitting", "Service Log", "Practice Session"]
        case .audio: return ["Enable live listening", "Audio interface", "Input channel", "Input gain", "Noise gate", "Pause during music", "Auto-pause after silence", "Speech engine", "Language", "Custom vocabulary", "Keep transcripts for"]
        case .detection: return ["Enable detection", "Bible translation", "Second translation", "Show abbreviation", "Recognize", "Follow-up verses", "Verse ranges", "Quoted scripture", "Minimum confidence", "Detection speed"]
        case .output: return ["Presentation app", "Connection method", "Port", "Test Connection", "Reconnect automatically", "When a verse is sent", "Verses per slide", "Surrounding verses", "Clear the screen after", "Sound when waiting", "Dismiss unsent after", "Pair with app", "Show when app opens", "Open app with Word Cue", "When the app quits", "Snap app beside Word Cue"]
        case .appearance: return ["Appearance", "Accent color", "Panel position", "Panel opacity", "Show confidence", "Keep panel on top", "Menu bar icon", "Listening status", "Waiting verse in menu bar", "Live Transcript"]
        case .shortcuts: return ["Send", "Skip", "Pause or resume listening", "Clear screen", "Resend last verse", "Switch compact / full", "Show or hide Word Cue", "Undo a file drop", "Shortcuts work while your app is in front"]
        case .filters: return ["Require a chapter number", "Ignored phrases", "Ignored books", "Duplicate cooldown"]
        case .advanced: return ["Buffer size", "On-device model", "Debug logging", "Diagnostics report", "Connection override", "Reset all settings"]
        case .support: return ["Permissions", "Send Feedback", "Updates", "Backup", "Export settings", "Import settings"]
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var panel: SettingsPanel = .general
    @State private var search = ""

    private var results: [(name: String, panel: SettingsPanel)] {
        guard !search.isEmpty else { return [] }
        return SettingsPanel.allCases.flatMap { p in
            p.settingNames.filter { $0.localizedCaseInsensitiveContains(search) }.map { ($0, p) }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { panel }, set: { if let p = $0 { panel = p; search = "" } })) {
                if search.isEmpty {
                    ForEach(SettingsPanel.groups, id: \.0) { group in
                        Section(group.0) {
                            ForEach(group.1) { p in Label(p.rawValue, systemImage: p.icon).tag(p) }
                        }
                    }
                } else {
                    // Each result shows the setting and the panel it lives in.
                    ForEach(results, id: \.name) { r in
                        Button {
                            panel = r.panel
                            search = ""
                        } label: {
                            VStack(alignment: .leading) {
                                Text(r.name)
                                Text(r.panel.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $search, placement: .sidebar, prompt: "Search settings")
            .navigationSplitViewColumnWidth(210)
        } detail: {
            Group {
                switch panel {
                case .general: GeneralPanel()
                case .audio: AudioPanel()
                case .detection: DetectionPanel()
                case .output: OutputPanel()
                case .appearance: AppearancePanel()
                case .shortcuts: ShortcutsPanel()
                case .filters: FiltersPanel()
                case .advanced: AdvancedPanel()
                case .support: SupportPanel()
                }
            }
            .formStyle(.grouped)
            .navigationTitle(panel.rawValue)
        }
        .frame(minWidth: 760, minHeight: 540)
    }
}

/// A grey line of help under a control.
private func hint(_ text: String) -> some View {
    Text(text).font(.caption).foregroundStyle(.secondary)
}

private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

// MARK: - Home

struct GeneralPanel: View {
    @Environment(AppModel.self) private var model
    @State private var pickingPractice = false
    @State private var showingLog = false

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                HStack {
                    Circle().fill(model.isListening ? Theme.green : .gray).frame(width: 9, height: 9)
                    Text(model.isListening ? "Listening" : (model.status == .paused ? "Paused" : "Ready"))
                    Spacer()
                    Button(model.isListening ? "Pause" : "Start Listening") { model.togglePause() }
                }
            }
            Section("Cue mode") {
                Picker("Cue mode", selection: $settings.s.cueMode) {
                    Text("Review first").tag(CueMode.reviewFirst)
                    Text("Auto-send").tag(CueMode.autoSend)
                }
                .pickerStyle(.segmented)
                if settings.s.cueMode == .autoSend {
                    LabeledContent("Auto-send at") {
                        Slider(value: $settings.s.autoSendAt, in: 0.80...1.0, step: 0.01)
                        Text(percent(settings.s.autoSendAt)).monospacedDigit().frame(width: 44)
                    }
                    Text("With Auto-send on, confident verses reach the screen without anyone approving them. Anything below still waits.")
                        .font(.caption).foregroundStyle(Theme.yellow)
                } else {
                    hint("Every verse waits for Send.")
                }
            }
            Section("Startup") {
                Picker("Start listening", selection: $settings.s.startListening) {
                    Text("When your presentation app opens").tag(StartListening.whenAppOpens)
                    Text("Manually").tag(StartListening.manually)
                }
                Toggle("Launch at login", isOn: $settings.s.launchAtLogin)
                Toggle("Show menu bar icon", isOn: $settings.s.showMenuBarIcon)
                Toggle("Keep Mac awake while listening", isOn: $settings.s.keepMacAwake)
                Toggle("Confirm before quitting while listening", isOn: $settings.s.confirmBeforeQuitting)
            }
            Section("Quick links") {
                Button("Open Service Log\u{2026}") { showingLog = true }
                Button("Run a Practice Session\u{2026}") { pickingPractice = true }
                if let progress = model.practiceProgress { hint(progress) }
                Button("Run Setup Again") { model.showSetup = true }
                Link("Help & Setup Guides", destination: URL(string: "https://freshfirestudios.github.io/word-cue/")!)
            }
        }
        .fileImporter(isPresented: $pickingPractice, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result { model.runPractice(url) }
        }
        .sheet(isPresented: $showingLog) { ServiceLogView().environment(model) }
    }
}

/// A record of every verse in a service, exportable for the pastor.
struct ServiceLogView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var exported = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Service Log").font(.title2.weight(.semibold))
            List {
                ForEach(model.pastServices) { service in
                    Section(service.started.formatted(date: .complete, time: .shortened)) {
                        ForEach(service.entries) { e in
                            HStack {
                                Text(e.time.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                                Text(e.title)
                                Spacer()
                                Text(e.outcome.rawValue).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if !exported.isEmpty { Text(exported).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button("Show in Finder") { NSWorkspace.shared.open(model.logFolder) }
                Button("Export This Service") {
                    if let url = try? FeedbackReporter.save(model.exportServiceLog(), name: "Service Log") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                        exported = "Saved as a text file."
                    }
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 520, height: 460)
    }
}

// MARK: - Service

struct AudioPanel: View {
    @Environment(AppModel.self) private var model
    @State private var newWord = ""

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                HStack {
                    LevelMeter(level: model.level).frame(height: 8)
                    Text(model.speechDetected ? "Sound detected" : "Quiet").font(.caption).foregroundStyle(.secondary).frame(width: 100, alignment: .trailing)
                }
            }
            Section("Input") {
                Toggle("Enable live listening", isOn: $settings.s.liveListening)
                Picker("Audio interface", selection: $settings.s.inputDeviceUID) {
                    Text("System default").tag("")
                    ForEach(model.inputDevices) { Text($0.name).tag($0.uid) }
                }
                Picker("Input channel", selection: $settings.s.inputChannel) {
                    Text("Mix of all channels").tag(0)
                    ForEach(1...max(1, AudioInput.channelCount(uid: settings.s.inputDeviceUID)), id: \.self) { Text("Channel \($0)").tag($0) }
                }
                LabeledContent("Input gain") {
                    Slider(value: $settings.s.inputGainDB, in: 0...24, step: 1)
                    Text("+\(Int(settings.s.inputGainDB)) dB").monospacedDigit().frame(width: 56)
                }
                LabeledContent("Noise gate") {
                    Slider(value: $settings.s.noiseGateDB, in: -70...(-20), step: 1)
                    Text("\(Int(settings.s.noiseGateDB)) dB").monospacedDigit().frame(width: 56)
                }
                hint("Changes to the input apply the next time you start listening.")
            }
            Section("Pausing") {
                Toggle("Pause during music", isOn: $settings.s.pauseDuringMusic)
                Picker("Auto-pause after silence", selection: $settings.s.autoPauseAfterSilenceMinutes) {
                    Text("2 minutes").tag(2)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("Never").tag(0)
                }
            }
            Section("Speech") {
                Picker("Speech engine", selection: $settings.s.speechEngine) {
                    Text("Standard").tag(SpeechEngineChoice.standard)
                    Text("Enhanced").tag(SpeechEngineChoice.enhanced)
                }
                Picker("Language", selection: $settings.s.language) {
                    Text("English (US)").tag("en-US")
                    Text("Spanish").tag("es-US")
                }
                LabeledContent("Custom vocabulary") {
                    VStack(alignment: .leading) {
                        ForEach(settings.s.customVocabulary, id: \.self) { word in
                            HStack {
                                Text(word)
                                Spacer()
                                Button { settings.s.customVocabulary.removeAll { $0 == word } } label: { Image(systemName: "minus.circle") }
                                    .buttonStyle(.plain).accessibilityLabel("Remove \(word)")
                            }
                        }
                        TextField("Add a word or name", text: $newWord)
                            .onSubmit {
                                let w = newWord.trimmingCharacters(in: .whitespaces)
                                if !w.isEmpty && !settings.s.customVocabulary.contains(w) { settings.s.customVocabulary.append(w) }
                                newWord = ""
                            }
                    }
                }
                hint("Words your pastor uses often: names, places, Apostolic terms.")
            }
            Section("Privacy") {
                Picker("Keep transcripts for", selection: $settings.s.keepTranscriptsDays) {
                    Text("This service only").tag(0)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("Don\u{2019}t keep").tag(-1)
                }
                hint("Audio is never saved.")
            }
        }
        .onAppear {
            model.refreshDevices()
            model.startLevelCheck()
        }
        .onDisappear { model.stopLevelCheck() }
    }
}

struct DetectionPanel: View {
    @Environment(AppModel.self) private var model
    @State private var sample = "Turn with me to Acts chapter two and verse thirty eight"

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Preview") {
                TextField("Sample sentence", text: $sample)
                let found = model.engine.detect(sample, quotes: settings.s.recognizeQuotedScripture)
                if let d = found.first {
                    HStack {
                        Text(model.engine.display(d.reference)).font(.title3.weight(.bold))
                        Text(percent(d.confidence)).foregroundStyle(.secondary)
                        Spacer()
                        Text(d.confidence >= settings.s.minimumConfidence ? "Likely Match" : "Below your minimum").foregroundStyle(.secondary)
                    }
                } else {
                    hint("No reference found in that sentence.")
                }
            }
            Section("Detection") {
                Toggle("Enable detection", isOn: $settings.s.detectionEnabled)
                Picker("Bible translation", selection: $settings.s.translation) { Text("KJV").tag("KJV") }
                hint("NKJV and ESV are licensed translations and are not included yet.")
                Toggle("Show abbreviation on the slide", isOn: $settings.s.showAbbreviation)
            }
            Section("Recognize") {
                LabeledContent("Written and spoken references") { Text("Always on").foregroundStyle(.secondary) }
                Toggle("Verse ranges", isOn: $settings.s.recognizeRanges)
                Toggle("Follow-up verses", isOn: $settings.s.recognizeFollowUps)
                Toggle("Quoted scripture (Beta)", isOn: $settings.s.recognizeQuotedScripture)
                hint("Quoted scripture matches spoken verse text to the Bible when no reference is said.")
            }
            Section("Confidence") {
                LabeledContent("Minimum confidence") {
                    Slider(value: $settings.s.minimumConfidence, in: 0.4...0.95, step: 0.05)
                    Text(percent(settings.s.minimumConfidence)).monospacedDigit().frame(width: 44)
                }
                Picker("Detection speed", selection: $settings.s.detectionSpeed) {
                    Text("Faster").tag(DetectionSpeed.faster)
                    Text("Balanced").tag(DetectionSpeed.balanced)
                    Text("More accurate").tag(DetectionSpeed.moreAccurate)
                }
                hint("More accurate waits for the full sentence before showing a verse.")
            }
        }
    }
}

struct OutputPanel: View {
    @Environment(AppModel.self) private var model
    @State private var testing = false

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Connection") {
                Picker("Presentation app", selection: $settings.s.presentationApp) {
                    ForEach(PresentationApp.allCases) { Text($0.displayName).tag($0) }
                }
                hint(settings.s.presentationApp.setupHint)
                Picker("Connection method", selection: $settings.s.connectionMethod) {
                    Text("Automatic").tag(ConnectionMethod.automatic)
                    Text("API only").tag(ConnectionMethod.apiOnly)
                    Text("Keyboard only").tag(ConnectionMethod.keyboardOnly)
                }
                if settings.s.presentationApp.hasAPI {
                    TextField("Port", value: $settings.s.port, format: .number.grouping(.never),
                              prompt: Text("Auto (\(String(settings.s.presentationApp.defaultPort)))"))
                }
                if settings.s.connectionMethod != .apiOnly || !settings.s.presentationApp.hasAPI {
                    TextField("Key that opens the app\u{2019}s Bible search", text: $settings.s.keyboardOpenSearch, prompt: Text("for example cmd+b"))
                    if !model.permissions.accessibility {
                        Button("Allow Accessibility\u{2026}") { KeyboardAdapter.requestPermission() }
                    }
                }
                HStack {
                    Button("Test Connection") {
                        testing = true
                        Task {
                            await model.checkConnection()
                            testing = false
                        }
                    }
                    if testing { ProgressView().controlSize(.small) }
                    Text(model.connectionNote).font(.callout).foregroundStyle(model.appConnected == true ? Theme.green : .secondary)
                }
                Toggle("Reconnect automatically", isOn: $settings.s.reconnectAutomatically)
            }
            Section("On screen") {
                Picker("When a verse is sent", selection: $settings.s.whenSent) {
                    Text("Go live immediately").tag(SendBehavior.goLive)
                    Text("Add to the service list").tag(SendBehavior.addToServiceList)
                }
                Picker("Verses per slide", selection: $settings.s.versesPerSlide) {
                    Text("1 verse").tag(1)
                    Text("2 verses").tag(2)
                    Text("Whole passage").tag(0)
                }
                Picker("Surrounding verses", selection: $settings.s.surroundingVerses) {
                    Text("None").tag(0)
                    Text("1 before and after").tag(1)
                }
                Picker("Clear the screen after", selection: $settings.s.clearScreenAfterMinutes) {
                    Text("Never").tag(0)
                    Text("1 minute").tag(1)
                    Text("2 minutes").tag(2)
                    Text("5 minutes").tag(5)
                }
            }
            Section("Waiting verses") {
                Toggle("Sound when a verse is waiting", isOn: $settings.s.soundWhenWaiting)
                Picker("Dismiss unsent after", selection: $settings.s.dismissUnsentAfterSeconds) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("Never").tag(0)
                }
            }
            Section("Working together") {
                Toggle("Pair with app", isOn: $settings.s.pairWithApp)
                Toggle("Show when app opens", isOn: $settings.s.showWhenAppOpens)
                Toggle("Open app with Word Cue", isOn: $settings.s.openAppWithWordCue)
                Picker("When the app quits", selection: $settings.s.whenAppQuits) {
                    Text("Hide Word Cue").tag(WhenAppQuits.hide)
                    Text("Quit Word Cue").tag(WhenAppQuits.quit)
                }
                Toggle("Snap app beside Word Cue", isOn: $settings.s.snapAppBeside)
                hint("Snapping needs Accessibility and is not built yet. macOS Stage Manager can also keep the two together.")
            }
        }
        .onAppear { model.refreshPermissions() }
    }
}

// MARK: - Customization

struct AppearancePanel: View {
    @Environment(AppModel.self) private var model
    private let accents: [(String, String)] = [("Fresh Fire", "F0A050"), ("Ember", "B85A1B"), ("Blue", "0A84FF"), ("Green", "34C759"), ("Graphite", "8E8E93")]

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Look") {
                Picker("Appearance", selection: $settings.s.appearance) {
                    Text("System").tag(AppearanceChoice.system)
                    Text("Light").tag(AppearanceChoice.light)
                    Text("Dark").tag(AppearanceChoice.dark)
                }
                .pickerStyle(.segmented)
                LabeledContent("Accent color") {
                    HStack {
                        ForEach(accents, id: \.1) { name, hex in
                            Button { settings.s.accentHex = hex } label: {
                                Circle().fill(Theme.accent(hex)).frame(width: 20, height: 20)
                                    .overlay(Circle().strokeBorder(.primary, lineWidth: settings.s.accentHex == hex ? 2 : 0))
                            }
                            .buttonStyle(.plain)
                            .help(name)
                            .accessibilityLabel(name)
                        }
                    }
                }
                Toggle("Show Live Transcript in the sidebar", isOn: $settings.s.showLiveTranscript)
            }
            Section("Compact panel") {
                Picker("Panel position", selection: $settings.s.panelCorner) {
                    Text("Top left").tag(PanelCorner.topLeft)
                    Text("Top right").tag(PanelCorner.topRight)
                    Text("Bottom left").tag(PanelCorner.bottomLeft)
                    Text("Bottom right").tag(PanelCorner.bottomRight)
                }
                LabeledContent("Panel opacity") {
                    Slider(value: $settings.s.panelOpacity, in: 0.5...1, step: 0.05)
                    Text(percent(settings.s.panelOpacity)).monospacedDigit().frame(width: 44)
                }
                Toggle("Show confidence", isOn: $settings.s.showConfidence)
                Toggle("Keep panel on top", isOn: $settings.s.keepPanelOnTop)
            }
            Section("Menu bar") {
                Picker("Menu bar icon", selection: $settings.s.menuBarIcon) {
                    Label("Flame", systemImage: "flame.fill").tag(MenuBarIcon.flame)
                    Label("Waveform", systemImage: "waveform").tag(MenuBarIcon.waveform)
                    Label("Open book", systemImage: "book.fill").tag(MenuBarIcon.book)
                }
                Toggle("Icon turns orange while listening", isOn: $settings.s.menuBarShowsListening)
                Toggle("Show the waiting verse next to the icon", isOn: $settings.s.menuBarShowsWaitingVerse)
            }
        }
    }
}

struct ShortcutsPanel: View {
    @Environment(AppModel.self) private var model
    private let rows: [(String, String)] = [("send", "Send"), ("skip", "Skip"), ("pause", "Pause or resume listening"),
                                            ("clear", "Clear screen"), ("resend", "Resend last verse"),
                                            ("compact", "Switch compact / full"), ("undo", "Undo a file drop")]
    private let anywhere: Set<String> = ["send", "skip", "pause", "clear", "resend"]

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                    GridRow {
                        Text("Action").font(.caption).foregroundStyle(.secondary)
                        Text("In Word Cue").font(.caption).foregroundStyle(.secondary)
                        Text("Anywhere").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(rows, id: \.0) { key, label in
                        GridRow {
                            Text(label)
                            KeyRecorder(text: Binding(get: { settings.s.shortcuts[key] ?? "" }, set: { settings.s.shortcuts[key] = $0 }))
                            if anywhere.contains(key), let combo = KeyCombo(settings.s.shortcuts[key] ?? "") {
                                KeyCap(text: combo.anywhere.symbol).opacity(settings.s.anywhereShortcuts ? 1 : 0.35)
                            } else {
                                Text("\u{2014}").foregroundStyle(.tertiary)
                            }
                        }
                    }
                    GridRow {
                        Text("Show or hide Word Cue")
                        Text("\u{2014}").foregroundStyle(.tertiary)
                        KeyCap(text: "\u{2325}\u{2318}W").opacity(settings.s.anywhereShortcuts ? 1 : 0.35)
                    }
                }
                hint("Click a key, then press the new one. Anywhere keys add Control-Option so typing in your presentation app is never affected.")
            }
            Section {
                Toggle("Shortcuts work while your app is in front", isOn: $settings.s.anywhereShortcuts)
                Button("Reset to Defaults") { settings.s.shortcuts = WordCueSettings.defaultShortcuts }
            }
        }
    }
}

/// Click, then press a key to record it as the shortcut.
struct KeyRecorder: View {
    @Binding var text: String
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Press a key\u{2026}" : (KeyCombo(text)?.symbol ?? "None"))
                .font(.callout.monospaced())
                .frame(minWidth: 70)
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let names: [UInt16: String] = [36: "return", 53: "escape", 49: "space", 51: "delete", 123: "left", 124: "right", 125: "down", 126: "up"]
            let key = names[event.keyCode] ?? (event.charactersIgnoringModifiers ?? "").lowercased()
            guard !key.isEmpty else { return nil }
            var combo = ""
            if event.modifierFlags.contains(.control) { combo += "ctrl+" }
            if event.modifierFlags.contains(.option) { combo += "opt+" }
            if event.modifierFlags.contains(.shift) { combo += "shift+" }
            if event.modifierFlags.contains(.command) { combo += "cmd+" }
            text = combo + key
            stop()
            return nil      // swallow the key so it does not also trigger something
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}

struct FiltersPanel: View {
    @Environment(AppModel.self) private var model
    @State private var newPhrase = ""

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Require a chapter number") {
                hint("These book names are also everyday words. They only count as books when a chapter number follows, so \u{201C}mark my words\u{201D} never triggers a verse.")
                bookChips($settings.s.requireChapterBooks)
            }
            Section("Ignored phrases") {
                ForEach(settings.s.ignoredPhrases, id: \.self) { phrase in
                    HStack {
                        Text(phrase)
                        Spacer()
                        Button { settings.s.ignoredPhrases.removeAll { $0 == phrase } } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain).accessibilityLabel("Remove \(phrase)")
                    }
                }
                TextField("Add a phrase that should never trigger a verse", text: $newPhrase)
                    .onSubmit {
                        let p = newPhrase.trimmingCharacters(in: .whitespaces)
                        if !p.isEmpty && !settings.s.ignoredPhrases.contains(p) { settings.s.ignoredPhrases.append(p) }
                        newPhrase = ""
                    }
            }
            Section("Ignored books") {
                hint("Books Word Cue skips entirely.")
                bookChips($settings.s.ignoredBooks)
            }
            Section("Repeats") {
                LabeledContent("Duplicate cooldown") {
                    Slider(value: Binding(get: { Double(settings.s.duplicateCooldownSeconds) }, set: { settings.s.duplicateCooldownSeconds = Int($0) }),
                           in: 0...300, step: 15)
                    Text("\(settings.s.duplicateCooldownSeconds) s").monospacedDigit().frame(width: 50)
                }
                hint("The same verse won\u{2019}t appear again within this time.")
            }
        }
    }

    /// A menu to add a book, and a removable chip for each one chosen.
    private func bookChips(_ ids: Binding<[String]>) -> some View {
        VStack(alignment: .leading) {
            ForEach(ids.wrappedValue, id: \.self) { id in
                HStack {
                    Text(model.engine.book(id)?.name ?? id)
                    Spacer()
                    Button { ids.wrappedValue.removeAll { $0 == id } } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.plain).accessibilityLabel("Remove")
                }
            }
            Menu("Add a book") {
                ForEach(model.engine.books.filter { !ids.wrappedValue.contains($0.id) }, id: \.id) { b in
                    Button(b.name) { ids.wrappedValue.append(b.id) }
                }
            }
            .fixedSize()
        }
    }
}

// MARK: - System

struct AdvancedPanel: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false
    @State private var message = ""

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Audio") {
                Picker("Buffer size", selection: $settings.s.bufferSize) {
                    Text("Lower delay").tag(BufferSize.lowerDelay)
                    Text("Balanced").tag(BufferSize.balanced)
                    Text("More stable").tag(BufferSize.moreStable)
                }
                hint("More stable avoids dropouts on a busy Mac.")
            }
            Section("On-device model") {
                LabeledContent("Speech model") { Text("Managed by macOS").foregroundStyle(.secondary) }
                hint("The speech model downloads once and is kept up to date by macOS. Word Cue never uses a model from anywhere else.")
            }
            Section("Troubleshooting") {
                Toggle("Debug logging", isOn: $settings.s.debugLogging)
                Button("Open Logs Folder") { NSWorkspace.shared.open(DebugLog.folder) }
                Button("Export Diagnostics Report") {
                    let report = FeedbackReporter.build(kind: .other, note: "Diagnostics report", email: "", includeDiagnostics: true, settings: settings.s)
                    if let url = try? FeedbackReporter.save(report, name: "Diagnostics") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                        message = "Saved. It never contains audio or transcripts."
                    }
                }
                if !message.isEmpty { hint(message) }
            }
            Section("Connection override") {
                TextField("Host", text: $settings.s.host, prompt: Text("127.0.0.1"))
                SecureField("API password, if your app has one", text: $settings.s.apiPassword)
                TextField("ProPresenter message name", text: $settings.s.messageName)
                hint("For unusual setups only.")
            }
            Section {
                Button("Reset All Settings\u{2026}", role: .destructive) { confirmReset = true }
            }
        }
        .confirmationDialog("Return every setting to its default? This can\u{2019}t be undone.", isPresented: $confirmReset) {
            Button("Reset All Settings", role: .destructive) { model.settings.reset() }
        }
    }
}

struct SupportPanel: View {
    @Environment(AppModel.self) private var model
    @State private var kind: FeedbackReporter.Kind = .bug
    @State private var note = ""
    @State private var includeDiagnostics = true
    @State private var result = ""
    @State private var exporting = false
    @State private var importing = false

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Permissions") {
                permission("Microphone", model.permissions.microphone, "Privacy_Microphone")
                permission("Speech Recognition", model.permissions.speech, "Privacy_SpeechRecognition")
                permission("Accessibility", model.permissions.accessibility, "Privacy_Accessibility")
                HStack {
                    Label("Notifications", systemImage: model.permissions.notifications ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(model.permissions.notifications ? Theme.green : .secondary)
                    Spacer()
                    if !model.permissions.notifications {
                        Button("Turn On") { Task { _ = await SystemIntegration.requestNotifications(); model.refreshPermissions() } }
                    }
                }
                hint("Notifications alert you if audio or the presentation app drops while Word Cue is hidden.")
            }
            Section("Send Feedback") {
                Picker("Type", selection: $kind) {
                    ForEach(FeedbackReporter.Kind.allCases) { Text($0.rawValue).tag($0) }
                }
                TextEditor(text: $note).frame(height: 90)
                TextField("Email for a reply (optional)", text: $settings.s.feedbackEmail)
                Toggle("Include diagnostic info", isOn: $includeDiagnostics)
                hint("Diagnostic info is settings and recent logs only, never audio or transcripts.")
                HStack {
                    Button("Send Feedback") {
                        let report = FeedbackReporter.build(kind: kind, note: note, email: settings.s.feedbackEmail,
                                                            includeDiagnostics: includeDiagnostics, settings: settings.s)
                        Task { result = await FeedbackReporter.send(report) }
                    }
                    Text(result).font(.callout).foregroundStyle(.secondary)
                }
            }
            Section("Updates") {
                LabeledContent("Version") { Text(Updater.shared.currentVersion) }
                Picker("Channel", selection: $settings.s.updateChannel) {
                    Text("Stable").tag(UpdateChannel.stable)
                    Text("Beta").tag(UpdateChannel.beta)
                }
                Button("Check Now") { Updater.shared.checkNow() }.disabled(!Updater.shared.isAvailable)
                hint(Updater.shared.isAvailable ? "Updates never install during a service." : "Automatic updates are not set up in this build yet.")
            }
            Section("Backup") {
                Button("Export Settings\u{2026}") { exporting = true }
                Button("Import Settings\u{2026}") { importing = true }
                hint("Export settings to set up another church\u{2019}s Mac the same way.")
            }
        }
        .onAppear { model.refreshPermissions() }
        .fileExporter(isPresented: $exporting, document: SettingsFile(settings: settings.s), contentType: .json, defaultFilename: "Word Cue Settings") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { picked in
            guard case .success(let url) = picked else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let imported = try? WordCueSettings.imported(data) {
                model.settings.s = imported
                result = "Settings imported."
            } else {
                result = "That file is not a Word Cue settings file."
            }
        }
    }

    private func permission(_ name: String, _ granted: Bool, _ pane: String) -> some View {
        HStack {
            Label(name, systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? Theme.green : Theme.yellow)
            Spacer()
            if !granted { Button("Open System Settings") { SystemIntegration.openPrivacySettings(pane) } }
        }
    }
}

/// The exported settings file.
struct SettingsFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var settings: WordCueSettings

    init(settings: WordCueSettings) { self.settings = settings }

    init(configuration: ReadConfiguration) throws {
        settings = try WordCueSettings.imported(configuration.file.regularFileContents ?? Data())
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var s = settings
        s.apiPassword = ""      // never copy a password to another church's Mac
        s.feedbackEmail = ""
        return FileWrapper(regularFileWithContents: try s.exported())
    }
}
