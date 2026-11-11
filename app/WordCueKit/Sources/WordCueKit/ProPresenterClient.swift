// UNTESTED: written without a Swift compiler and never run against a real
// ProPresenter. Endpoints come from the official spec at
// https://openapi.propresenter.com (see docs/PROPRESENTER-API.md). The JSON
// body shapes marked VERIFY were read from a summary of that spec, so check
// them against a live ProPresenter before trusting them.
import Foundation

/// Where to find ProPresenter. In ProPresenter: Settings > Network >
/// turn on "Enable Network"; the port is shown on that screen.
public struct ProPresenterSettings: Codable, Equatable, Sendable {
    public var host = "127.0.0.1"      // same Mac. Use the other computer's IP address if ProPresenter runs elsewhere.
    public var port = 50001            // whatever ProPresenter's Network settings show
    public var messageName = "Word Cue"
    public init() {}
}

public struct ProPresenterVersion: Decodable, Sendable {
    public let name: String?
    public let platform: String?
    public let os_version: String?
    public let host_description: String?
    public let api_version: String?
}

public enum ProPresenterError: LocalizedError {
    case badAddress
    case notReachable(String)
    case http(Int, String)
    case messageMissing(String)

    public var errorDescription: String? {
        switch self {
        case .badAddress:
            return "The ProPresenter address is not valid. Check the host and port in Word Cue's settings."
        case .notReachable(let why):
            return "Could not reach ProPresenter. Is it open, with Settings > Network > Enable Network turned on? (\(why))"
        case .http(let code, let path):
            return "ProPresenter answered \(code) for \(path)."
        case .messageMissing(let name):
            return "ProPresenter has no message named \"\(name)\". Use Set Up in Word Cue's settings to create it."
        }
    }
}

/// Talks to ProPresenter 7's network API.
///
/// The API has no "show this Bible verse" command (checked Nov 2026), so
/// Word Cue sends the verse through a ProPresenter **Message**: a text
/// overlay with blanks ("tokens") that Word Cue fills with the verse text
/// and the reference. ProPresenter's own Theme decides how it looks.
public actor ProPresenterClient {
    public static let verseToken = "Verse"
    public static let referenceToken = "Reference"

    private var settings: ProPresenterSettings
    private let session: URLSession

    public init(settings: ProPresenterSettings = ProPresenterSettings()) {
        self.settings = settings
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3      // a live service cannot wait long
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    public func update(_ settings: ProPresenterSettings) { self.settings = settings }

    // MARK: Requests (pure functions, easy to unit test)

    static func url(_ settings: ProPresenterSettings, _ path: String) -> URL? {
        var parts = URLComponents()
        parts.scheme = "http"
        parts.host = settings.host
        parts.port = settings.port
        parts.path = path        // URLComponents percent-encodes spaces in the message name
        return parts.url
    }

    static func request(_ settings: ProPresenterSettings, _ method: String, _ path: String, json: Any? = nil) throws -> URLRequest {
        guard let url = url(settings, path) else { throw ProPresenterError.badAddress }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let json {
            request.httpBody = try JSONSerialization.data(withJSONObject: json, options: [.fragmentsAllowed])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    /// VERIFY: body for POST /v1/message/{id}/trigger - a list of tokens to fill in.
    static func triggerBody(verse: String, reference: String) -> [[String: Any]] {
        [
            ["name": verseToken, "text": ["text": verse]],
            ["name": referenceToken, "text": ["text": reference]]
        ]
    }

    /// VERIFY: body for POST /v1/messages - creates the "Word Cue" message.
    /// The message text holds {Verse} and {Reference} blanks.
    static func createBody(name: String) -> [String: Any] {
        [
            "id": ["name": name, "uuid": UUID().uuidString, "index": 0],
            "message": "{\(verseToken)}\n{\(referenceToken)}",
            "tokens": triggerBody(verse: "", reference: ""),
            "visible_on_network": true
        ]
    }

    @discardableResult
    private func send(_ method: String, _ path: String, json: Any? = nil) async throws -> Data {
        let request = try Self.request(settings, method, path, json: json)
        do {
            let (data, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else { throw ProPresenterError.http(code, path) }
            return data
        } catch let error as ProPresenterError {
            throw error
        } catch {
            throw ProPresenterError.notReachable(error.localizedDescription)
        }
    }

    // MARK: Commands

    /// GET /version - used by the "Test Connection" button.
    public func version() async throws -> ProPresenterVersion {
        try JSONDecoder().decode(ProPresenterVersion.self, from: try await send("GET", "/version"))
    }

    /// GET /v1/messages - is our message there?
    public func messageExists() async throws -> Bool {
        let data = try await send("GET", "/v1/messages")
        guard let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return false }
        return list.contains { (($0["id"] as? [String: Any])?["name"] as? String) == settings.messageName }
    }

    /// POST /v1/messages - one-time setup. Does nothing if the message exists.
    public func createMessageIfNeeded() async throws {
        if try await messageExists() { return }
        try await send("POST", "/v1/messages", json: Self.createBody(name: settings.messageName))
    }

    /// POST /v1/message/{id}/trigger - puts a verse on screen.
    public func show(verse: String, reference: String) async throws {
        do {
            try await send("POST", "/v1/message/\(settings.messageName)/trigger",
                           json: Self.triggerBody(verse: verse, reference: reference))
        } catch ProPresenterError.http(404, _) {
            throw ProPresenterError.messageMissing(settings.messageName)
        }
    }

    /// GET /v1/message/{id}/clear - takes the verse off screen.
    public func clear() async throws {
        try await send("GET", "/v1/message/\(settings.messageName)/clear")
    }

    /// PUT /v1/stage/message - shows text on the stage display (what the
    /// preacher sees), not the audience screen. The body is a JSON string.
    public func showOnStage(_ text: String) async throws {
        try await send("PUT", "/v1/stage/message", json: text)
    }

    /// DELETE /v1/stage/message
    public func clearStage() async throws {
        try await send("DELETE", "/v1/stage/message")
    }
}
