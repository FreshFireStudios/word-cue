// UNTESTED: written without Xcode and never run against a real ProPresenter.
import AppKit
import WordCueKit

enum SendResult: Equatable {
    case shown                 // ProPresenter took it through the API
    case copied(String)        // API failed: reference copied, ProPresenter brought forward. String = why.
}

/// Gets a verse onto the screen: ProPresenter's API first, and if that fails,
/// copy the reference and switch to ProPresenter so the operator can paste it
/// into ProPresenter's own Bible search.
final class PresentationSender {
    static let proPresenterBundleID = "com.renewedvision.propresenter"   // VERIFY on the Mac
    private let client: ProPresenterClient

    init(settings: ProPresenterSettings) {
        client = ProPresenterClient(settings: settings)
    }

    func update(_ settings: ProPresenterSettings) async { await client.update(settings) }

    func show(verse: Verse, title: String, alsoOnStage: Bool) async -> SendResult {
        do {
            try await client.show(verse: verse.text, reference: "\(title) KJV")
            if alsoOnStage { try? await client.showOnStage(title) }
            return .shown
        } catch {
            await MainActor.run { Self.copyAndSwitch(title) }
            return .copied(error.localizedDescription)
        }
    }

    func clear() async {
        try? await client.clear()
        try? await client.clearStage()
    }

    func testConnection() async -> Result<String, Error> {
        do {
            let v = try await client.version()
            let hasMessage = try await client.messageExists()
            let name = v.name ?? "ProPresenter"
            return .success(hasMessage ? "Connected to \(name). The Word Cue message is ready."
                                       : "Connected to \(name). Click Set Up Message to finish.")
        } catch {
            return .failure(error)
        }
    }

    func setUpMessage() async -> Result<String, Error> {
        do {
            try await client.createMessageIfNeeded()
            return .success("The Word Cue message is in ProPresenter. Pick a Theme for it there.")
        } catch {
            return .failure(error)
        }
    }

    @MainActor
    static func copyAndSwitch(_ reference: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reference, forType: .string)
        NSRunningApplication.runningApplications(withBundleIdentifier: proPresenterBundleID).first?.activate()
    }
}
