// UNTESTED: written without Xcode.
// Decides how a verse reaches the presentation app. "Automatic" means the
// app's API first, and keyboard typing if the API fails, so the service
// keeps going (User Guide section 02).
import Foundation
import WordCueKit

enum SendOutcome: Equatable {
    case sent(String)          // how it went: "API" or "keyboard"
    case failed(String)        // a line to show in the red banner
}

final class OutputRouter: @unchecked Sendable {
    private func adapters(_ s: WordCueSettings) -> [PresentationAdapter] {
        let api = Adapters.api(for: s)
        let keyboard: PresentationAdapter = KeyboardAdapter(settings: s)
        switch s.connectionMethod {
        case .apiOnly: return api.map { [$0] } ?? []
        case .keyboardOnly: return [keyboard]
        case .automatic: return (api.map { [$0] } ?? []) + [keyboard]
        }
    }

    private func attempt(_ s: WordCueSettings, _ work: (PresentationAdapter) async throws -> Void) async -> SendOutcome {
        var lastError = "No connection method is available for \(s.presentationApp.displayName)."
        for (i, adapter) in adapters(s).enumerated() {
            do {
                try await work(adapter)
                return .sent(adapter is KeyboardAdapter ? "keyboard" : "API")
            } catch {
                // keep the first (API) error: it is the one worth showing
                if i == 0 { lastError = error.localizedDescription }
            }
        }
        return .failed(lastError)
    }

    func send(_ item: VerseItem, settings s: WordCueSettings) async -> SendOutcome {
        if s.whenSent == .addToServiceList {
            let added = await attempt(s) { try await $0.addToServiceList(item) }
            if case .sent = added { return added }      // otherwise fall through and go live
        }
        return await attempt(s) { try await $0.show(item) }
    }

    func addToServiceList(_ item: VerseItem, settings s: WordCueSettings) async -> SendOutcome {
        await attempt(s) { try await $0.addToServiceList(item) }
    }

    func clear(settings s: WordCueSettings) async -> SendOutcome {
        await attempt(s) { try await $0.clear() }
    }

    /// For the Test Connection button and the status row's check mark.
    func test(settings s: WordCueSettings) async -> Result<String, Error> {
        var last: Error = AdapterError.notReachable("no connection method")
        for adapter in adapters(s) {
            do { return .success(try await adapter.test()) } catch { last = error }
        }
        return .failure(last)
    }
}
