// UNTESTED: written without a Swift compiler and never run against the real apps.
// One adapter per presentation app (User Guide section 02). Each is separate,
// so a new app can be added without touching the others.
//   ProPresenter: official API, verse sent as a Message (see docs/PROPRESENTER-API.md)
//   FreeShow:     confirmed from freeshow.app/api (Nov 2026)
//   OpenLP:       VERIFY - written from memory of the Remote API v2, not checked against docs
// EasyWorship and "Other" have no API; the app target's KeyboardAdapter types for them.
import Foundation

/// What gets sent: one verse (or a few) ready for the screen.
public struct VerseItem: Sendable, Equatable {
    public var reference: Reference
    public var title: String          // "Acts 2:38"
    public var text: String           // the verse text Word Cue looked up
    public var translation: String    // "KJV", or "" to leave it off
    public init(reference: Reference, title: String, text: String, translation: String) {
        self.reference = reference
        self.title = title
        self.text = text
        self.translation = translation
    }
    public var caption: String { translation.isEmpty ? title : "\(title) \(translation)" }
}

public enum AdapterError: LocalizedError {
    case notSupported(String)
    case notReachable(String)
    case http(Int, String)
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .notSupported(let what): return what
        case .notReachable(let why): return "Could not reach the presentation app. Is it open, with its remote setting on? (\(why))"
        case .http(let code, let path): return "The presentation app answered \(code) for \(path)."
        case .notFound(let what): return "The presentation app could not find \(what)."
        }
    }
}

public protocol PresentationAdapter: Sendable {
    var appName: String { get }
    /// Checks the connection without changing the screen. Returns a line to show the operator.
    func test() async throws -> String
    /// Puts the verse on screen now.
    func show(_ item: VerseItem) async throws
    /// Adds the verse to the app's service list or playlist without going live.
    func addToServiceList(_ item: VerseItem) async throws
    /// Takes the verse off screen.
    func clear() async throws
}

/// Small shared HTTP helper for the API adapters.
struct AdapterHTTP: Sendable {
    let host: String
    let port: Int
    var bearer = ""
    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 3       // a live service cannot wait long
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    @discardableResult
    func send(_ method: String, _ path: String, query: [String: String] = [:], json: Any? = nil) async throws -> Data {
        var parts = URLComponents()
        parts.scheme = "http"
        parts.host = host
        parts.port = port
        parts.path = path
        if !query.isEmpty { parts.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let url = parts.url else { throw AdapterError.notReachable("bad address") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if !bearer.isEmpty { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        if let json {
            request.httpBody = try JSONSerialization.data(withJSONObject: json, options: [.fragmentsAllowed])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        do {
            let (data, response) = try await Self.session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else { throw AdapterError.http(code, path) }
            return data
        } catch let error as AdapterError {
            throw error
        } catch {
            throw AdapterError.notReachable(error.localizedDescription)
        }
    }
}

// MARK: - ProPresenter

public struct ProPresenterAdapter: PresentationAdapter {
    public let appName = "ProPresenter"
    private let client: ProPresenterClient

    public init(settings: WordCueSettings) {
        var s = ProPresenterSettings()
        s.host = settings.host
        s.port = settings.effectivePort
        s.messageName = settings.messageName
        client = ProPresenterClient(settings: s)
    }

    public func test() async throws -> String {
        let v = try await client.version()
        let ready = try await client.messageExists()
        if !ready { try await client.createMessageIfNeeded() }
        return "Connected to \(v.name ?? "ProPresenter") through its API."
    }

    public func show(_ item: VerseItem) async throws {
        try await client.show(verse: item.text, reference: item.caption)
    }

    public func addToServiceList(_ item: VerseItem) async throws {
        throw AdapterError.notSupported("ProPresenter's API cannot add a Bible verse to a playlist. The verse stays in Word Cue's list instead.")
    }

    public func clear() async throws { try await client.clear() }
}

// MARK: - FreeShow

public struct FreeShowAdapter: PresentationAdapter {
    public let appName = "FreeShow"
    private let http: AdapterHTTP

    public init(settings: WordCueSettings) {
        http = AdapterHTTP(host: settings.host, port: settings.effectivePort, bearer: settings.apiPassword)
    }

    private func action(_ id: String, _ data: [String: Any] = [:]) async throws {
        var body = data
        body["action"] = id
        try await http.send("POST", "/", json: body)
    }

    public func test() async throws -> String {
        try await action("get_cleared")      // a read-only action: changes nothing on screen
        return "Connected to FreeShow through its API."
    }

    /// FreeShow looks the verse up in its own Bible, so it uses the church's translation and template.
    public func show(_ item: VerseItem) async throws {
        try await action("start_scripture", ["reference": item.title])
    }

    /// VERIFY: creates a show holding the verse text, named after the reference.
    public func addToServiceList(_ item: VerseItem) async throws {
        try await action("create_show", ["text": item.text + "\n" + item.caption, "name": item.title, "category": "Word Cue"])
    }

    public func clear() async throws { try await action("clear_slide") }
}

// MARK: - OpenLP

/// VERIFY every call here against OpenLP's Remote API before trusting it.
public struct OpenLPAdapter: PresentationAdapter {
    public let appName = "OpenLP"
    private let http: AdapterHTTP

    public init(settings: WordCueSettings) {
        http = AdapterHTTP(host: settings.host, port: settings.effectivePort)
    }

    public func test() async throws -> String {
        try await http.send("GET", "/api/v2/core/system")
        return "Connected to OpenLP through its Remote API."
    }

    /// Asks OpenLP's Bible plugin for the reference and returns the id of the first result.
    private func find(_ item: VerseItem) async throws -> Any {
        let data = try await http.send("GET", "/api/v2/plugins/bibles/search", query: ["text": item.title])
        guard let results = try JSONSerialization.jsonObject(with: data) as? [[Any]], let first = results.first?.first else {
            throw AdapterError.notFound(item.title)
        }
        return first
    }

    public func show(_ item: VerseItem) async throws {
        try await http.send("POST", "/api/v2/plugins/bibles/live", json: ["id": try await find(item)])
    }

    public func addToServiceList(_ item: VerseItem) async throws {
        try await http.send("POST", "/api/v2/plugins/bibles/add", json: ["id": try await find(item)])
    }

    public func clear() async throws {
        try await http.send("POST", "/api/v2/core/display", json: ["display": "blank"])
    }
}

public enum Adapters {
    /// The API adapter for the chosen app, or nil when the app has no API (keyboard only).
    public static func api(for settings: WordCueSettings) -> PresentationAdapter? {
        switch settings.presentationApp {
        case .proPresenter: return ProPresenterAdapter(settings: settings)
        case .freeShow: return FreeShowAdapter(settings: settings)
        case .openLP: return OpenLPAdapter(settings: settings)
        case .easyWorship, .other: return nil
        }
    }
}
