// UNTESTED: written without Xcode.
// Holds the church's settings (WordCueSettings from WordCueKit) and saves
// them every time one changes. Stored as one JSON file so it can be exported.
import Foundation
import Observation
import WordCueKit

@Observable
final class AppSettings {
    var s: WordCueSettings { didSet { if s != oldValue { save() } } }
    @ObservationIgnored var onChange: (() -> Void)?

    static let fileURL: URL = {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("Word Cue", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("settings.json")
    }()

    init() {
        if let data = try? Data(contentsOf: Self.fileURL), let saved = try? WordCueSettings.imported(data) {
            s = saved
        } else {
            s = WordCueSettings()
        }
    }

    private func save() {
        if let data = try? s.exported() { try? data.write(to: Self.fileURL, options: .atomic) }
        onChange?()
    }

    func reset() {
        let finished = s.finishedSetup
        s = WordCueSettings()
        s.finishedSetup = finished
    }
}
