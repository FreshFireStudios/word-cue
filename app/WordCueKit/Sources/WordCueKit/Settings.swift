// UNTESTED: written without a Swift compiler.
// Every setting from the User Guide, section 08, with the guide's defaults.
// One struct, saved as one JSON file, so "export settings to set up another
// church's Mac" is just copying that file.
import Foundation

public enum PresentationApp: String, Codable, CaseIterable, Sendable, Identifiable {
    case proPresenter, openLP, freeShow, easyWorship, other
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .proPresenter: return "ProPresenter"
        case .openLP: return "OpenLP"
        case .freeShow: return "FreeShow"
        case .easyWorship: return "EasyWorship"
        case .other: return "Other"
        }
    }

    /// Does the app have an API Word Cue can talk to?
    public var hasAPI: Bool { self == .proPresenter || self == .openLP || self == .freeShow }

    /// The port each app usually listens on. ProPresenter's is whatever its Network settings show.
    public var defaultPort: Int {
        switch self {
        case .proPresenter: return 50001
        case .openLP: return 4316
        case .freeShow: return 5506
        default: return 0
        }
    }

    /// VERIFY on the Mac: used to notice the app opening and to bring it forward.
    public var bundleIdentifiers: [String] {
        switch self {
        case .proPresenter: return ["com.renewedvision.propresenter"]
        case .openLP: return ["org.openlp.OpenLP", "org.openlp"]
        case .freeShow: return ["app.freeshow", "com.electron.freeshow"]
        case .easyWorship: return ["com.softouch.easyworship"]
        case .other: return []
        }
    }

    /// The one-line setup shown in Word Cue for each app (User Guide section 02).
    public var setupHint: String {
        switch self {
        case .proPresenter: return "In ProPresenter, open Settings > Network, turn on Enable Network, and note the port."
        case .openLP: return "In OpenLP, open Settings > Remote Interface and turn it on. Word Cue connects on port 4316."
        case .freeShow: return "In FreeShow, open Settings > Connections and turn on the API."
        case .easyWorship: return "Nothing to turn on in EasyWorship. Allow Accessibility when macOS asks."
        case .other: return "Nothing to turn on in the app. Allow Accessibility; Word Cue types the reference for you."
        }
    }
}

public enum CueMode: String, Codable, CaseIterable, Sendable { case reviewFirst, autoSend }
public enum ConnectionMethod: String, Codable, CaseIterable, Sendable { case automatic, apiOnly, keyboardOnly }
public enum SendBehavior: String, Codable, CaseIterable, Sendable { case goLive, addToServiceList }
public enum StartListening: String, Codable, CaseIterable, Sendable { case whenAppOpens, manually }
public enum WhenAppQuits: String, Codable, CaseIterable, Sendable { case hide, quit }
public enum SpeechEngineChoice: String, Codable, CaseIterable, Sendable { case standard, enhanced }
public enum DetectionSpeed: String, Codable, CaseIterable, Sendable { case faster, balanced, moreAccurate }
public enum BufferSize: String, Codable, CaseIterable, Sendable {
    case lowerDelay, balanced, moreStable
    public var frames: UInt32 { self == .lowerDelay ? 512 : (self == .balanced ? 1024 : 4096) }
}
public enum AppearanceChoice: String, Codable, CaseIterable, Sendable { case system, light, dark }
public enum PanelCorner: String, Codable, CaseIterable, Sendable { case topLeft, topRight, bottomLeft, bottomRight }
public enum MenuBarIcon: String, Codable, CaseIterable, Sendable {
    case flame, waveform, book
    public var symbol: String { self == .flame ? "flame.fill" : (self == .waveform ? "waveform" : "book.fill") }
}
public enum UpdateChannel: String, Codable, CaseIterable, Sendable { case stable, beta }

public struct WordCueSettings: Codable, Equatable, Sendable {
    // General
    public var cueMode: CueMode = .reviewFirst
    public var autoSendAt: Double = 0.95              // 0.80 ... 1.00
    public var startListening: StartListening = .whenAppOpens
    public var launchAtLogin = true
    public var showMenuBarIcon = true
    public var keepMacAwake = true
    public var confirmBeforeQuitting = true
    public var finishedSetup = false

    // Audio Input
    public var liveListening = true
    public var inputDeviceUID = ""                    // empty = system default
    public var inputChannel = 1                       // 1-based; 0 = mix all channels
    public var inputGainDB: Double = 6
    public var noiseGateDB: Double = -45
    public var pauseDuringMusic = true
    public var autoPauseAfterSilenceMinutes = 2       // 0 = never
    public var speechEngine: SpeechEngineChoice = .enhanced
    public var language = "en-US"                     // or "es-US"
    public var customVocabulary: [String] = ["Apostolic", "Pentecost", "Holy Ghost"]
    public var keepTranscriptsDays = 7                // 0 = this service only, -1 = don't keep

    // Scripture Detection
    public var detectionEnabled = true
    public var translation = "KJV"
    public var secondTranslation = ""
    public var showAbbreviation = true
    public var recognizeFollowUps = true
    public var recognizeRanges = true
    public var recognizeQuotedScripture = false       // Beta
    public var minimumConfidence: Double = 0.70
    public var detectionSpeed: DetectionSpeed = .balanced

    // Verse Output
    public var presentationApp: PresentationApp = .proPresenter
    public var connectionMethod: ConnectionMethod = .automatic
    public var host = "127.0.0.1"
    public var port = 0                               // 0 = the app's usual port
    public var apiPassword = ""                       // FreeShow / OpenLP, if the church set one
    public var messageName = "Word Cue"               // ProPresenter message that carries the verse
    public var reconnectAutomatically = true
    public var whenSent: SendBehavior = .goLive
    public var versesPerSlide = 1                     // 1, 2, or 0 = whole passage
    public var surroundingVerses = 0                  // 0 none, 1 = one before and after
    public var clearScreenAfterMinutes = 0            // 0 = never
    public var soundWhenWaiting = false
    public var dismissUnsentAfterSeconds = 30         // 0 = never
    public var pairWithApp = true
    public var showWhenAppOpens = true
    public var openAppWithWordCue = false
    public var whenAppQuits: WhenAppQuits = .hide
    public var snapAppBeside = false
    /// Keyboard mode: the keystroke that opens the app's Bible search, e.g. "cmd+b". Empty = just type.
    public var keyboardOpenSearch = ""

    // Appearance
    public var appearance: AppearanceChoice = .system
    public var accentHex = "F0A050"
    public var panelCorner: PanelCorner = .topRight
    public var panelOpacity: Double = 0.95
    public var showConfidence = true
    public var keepPanelOnTop = true
    public var menuBarIcon: MenuBarIcon = .flame
    public var menuBarShowsListening = true
    public var menuBarShowsWaitingVerse = false
    public var showLiveTranscript = false
    public var compact = false

    // Shortcuts & Controls
    public var anywhereShortcuts = true
    public var shortcuts: [String: String] = WordCueSettings.defaultShortcuts

    // Filters
    public var requireChapterBooks: [String] = ["MRK", "JOB", "ACT", "NUM", "JDG", "REV", "LAM"]
    public var ignoredPhrases: [String] = []
    public var ignoredBooks: [String] = []
    public var duplicateCooldownSeconds = 60

    // Advanced
    public var bufferSize: BufferSize = .balanced
    public var debugLogging = false

    // Support
    public var updateChannel: UpdateChannel = .stable
    public var feedbackEmail = ""

    public init() {}

    /// Action -> key while Word Cue is in front. "Anywhere" adds Control-Option to the same key.
    public static let defaultShortcuts: [String: String] = [
        "send": "return", "skip": "escape", "pause": "space",
        "clear": "cmd+b", "resend": "cmd+r", "compact": "cmd+\\", "undo": "cmd+z"
    ]

    public var effectivePort: Int { port > 0 ? port : presentationApp.defaultPort }

    public func exported() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(self)
    }

    public static func imported(_ data: Data) throws -> WordCueSettings {
        try JSONDecoder().decode(WordCueSettings.self, from: data)
    }
}
