// UNTESTED: written without Xcode.
import Foundation
import Observation
import WordCueKit

/// Everything the church can change, saved between launches.
@Observable
final class AppSettings {
    private let store = UserDefaults.standard

    var proPresenter: ProPresenterSettings { didSet { save(proPresenter, "proPresenter") } }
    var inputDeviceUID: String { didSet { store.set(inputDeviceUID, forKey: "inputDeviceUID") } }
    /// Suggestions below this score are not shown at all.
    var minimumConfidence: Double { didSet { store.set(minimumConfidence, forKey: "minimumConfidence") } }
    /// Off by default: nothing reaches the screen without the operator.
    var autoSend: Bool { didSet { store.set(autoSend, forKey: "autoSend") } }
    var autoSendThreshold: Double { didSet { store.set(autoSendThreshold, forKey: "autoSendThreshold") } }
    var keepOnTop: Bool { didSet { store.set(keepOnTop, forKey: "keepOnTop") } }
    var alsoShowOnStage: Bool { didSet { store.set(alsoShowOnStage, forKey: "alsoShowOnStage") } }
    var showTranscript: Bool { didSet { store.set(showTranscript, forKey: "showTranscript") } }

    init() {
        store.register(defaults: [
            "minimumConfidence": 0.5, "autoSend": false, "autoSendThreshold": 0.9,
            "keepOnTop": true, "alsoShowOnStage": false, "showTranscript": true, "inputDeviceUID": ""
        ])
        if let data = store.data(forKey: "proPresenter"),
           let saved = try? JSONDecoder().decode(ProPresenterSettings.self, from: data) {
            proPresenter = saved
        } else {
            proPresenter = ProPresenterSettings()
        }
        inputDeviceUID = store.string(forKey: "inputDeviceUID") ?? ""
        minimumConfidence = store.double(forKey: "minimumConfidence")
        autoSend = store.bool(forKey: "autoSend")
        autoSendThreshold = store.double(forKey: "autoSendThreshold")
        keepOnTop = store.bool(forKey: "keepOnTop")
        alsoShowOnStage = store.bool(forKey: "alsoShowOnStage")
        showTranscript = store.bool(forKey: "showTranscript")
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { store.set(data, forKey: key) }
    }
}
