// UNTESTED: written without Xcode.
// Sparkle is not added to the project yet: it needs a signing key pair and an
// update-feed address, which should be made on Bryson's Mac. Once the Sparkle
// package is added, the code inside `#if canImport(Sparkle)` takes over.
import Foundation
#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class Updater {
    static let shared = Updater()
    /// Set by AppModel: updates must never install during a service.
    var isServiceRunning: () -> Bool = { false }

    #if canImport(Sparkle)
    private let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    var isAvailable: Bool { true }
    func checkNow() {
        guard !isServiceRunning() else { return }
        controller.checkForUpdates(nil)
    }
    #else
    var isAvailable: Bool { false }
    func checkNow() {}
    #endif

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}
