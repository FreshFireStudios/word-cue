// UNTESTED: written without Xcode.
import SwiftUI
import Observation
import WordCueKit

@MainActor
@Observable
final class LabModel {
    var sessions: [LabSession] = []
    var selectedID: LabSession.ID?
    var findings: [LabFinding] = []
    var quotes = true
    var minimumConfidence = 0.0
    var busy: String?            // "Transcribing…" while work is running
    var message = ""
    var tryText = "Turn with me to Acts chapter two and verse thirty eight"

    let engine = Engine()
    let store = LabStore()

    var selected: LabSession? { sessions.first { $0.id == selectedID } }

    init() { reload() }

    func reload() {
        sessions = store.sessions()
        if selectedID == nil { selectedID = sessions.first?.id }
        rerun()
    }

    /// Runs the detector again over the selected session.
    func rerun() {
        guard let s = selected else {
            findings = []
            return
        }
        findings = LabStore.findings(in: s, engine: engine, quotes: quotes, minimumConfidence: minimumConfidence)
    }

    private func update(_ change: (inout LabSession) -> Void) {
        guard let i = sessions.firstIndex(where: { $0.id == selectedID }) else { return }
        change(&sessions[i])
        store.save(sessions[i])
        rerun()
    }

    // MARK: Importing

    func importRecording(_ url: URL) {
        var session = LabSession(name: url.deletingPathExtension().lastPathComponent)
        session.transcribedBy = "Apple SpeechTranscriber"
        sessions.insert(session, at: 0)
        selectedID = session.id
        busy = "Transcribing \(url.lastPathComponent) on this Mac\u{2026}"
        let id = session.id
        let vocabulary = engine.vocabulary
        Task {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                try await FileTranscriber.transcribe(url, vocabulary: vocabulary) { [weak self] segment in
                    Task { @MainActor in
                        guard let self, let i = self.sessions.firstIndex(where: { $0.id == id }) else { return }
                        self.sessions[i].segments.append(segment)
                        if self.sessions[i].segments.count % 20 == 0 { self.rerun() }
                    }
                }
                message = "Transcribed."
            } catch {
                message = "Could not transcribe: \(error.localizedDescription)"
            }
            if let i = sessions.firstIndex(where: { $0.id == id }) { store.save(sessions[i]) }
            busy = nil
            rerun()
        }
    }

    func importTranscript(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        var session = LabSession(name: url.deletingPathExtension().lastPathComponent)
        session.segments = LabStore.segments(fromTranscript: data)
        session.transcribedBy = "imported text"
        store.save(session)
        sessions.insert(session, at: 0)
        selectedID = session.id
        message = "Imported \(session.segments.count) segments."
        rerun()
    }

    /// A corrections file a church exported from Word Cue's Service Log.
    func importCorrections(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let cases = LabStore.importCorrections(data)
        let total = store.propose(cases)
        message = "Added \(cases.count) church correction(s). \(total) proposed cases in all."
    }

    func deleteSelected() {
        guard let s = selected else { return }
        store.delete(s)
        sessions.removeAll { $0.id == s.id }
        selectedID = sessions.first?.id
        rerun()
    }

    // MARK: Reviewing

    func review(_ finding: LabFinding, _ verdict: LabReview.Verdict?, corrected: String = "") {
        update { s in
            guard let verdict else {
                s.reviews[finding.reviewKey] = nil
                return
            }
            let key = corrected.isEmpty ? nil : LabStore.key(for: corrected, engine: engine)
            s.reviews[finding.reviewKey] = LabReview(verdict: verdict, correctedKey: key)
        }
    }

    func addMiss(text: String, expect: String) {
        guard let key = LabStore.key(for: expect, engine: engine) else {
            message = "Could not read \u{201C}\(expect)\u{201D} as a reference."
            return
        }
        update { $0.misses.append(LabMiss(text: text, expect: key)) }
        message = "Miss recorded: \(key)."
    }

    func removeMiss(_ id: LabMiss.ID) { update { s in s.misses.removeAll { $0.id == id } } }

    func proposeCases() {
        guard let s = selected else { return }
        let cases = LabStore.cases(from: s, findings: findings)
        guard !cases.isEmpty else {
            message = "Nothing to export yet. Mark a detection wrong or add a miss first."
            return
        }
        let total = store.propose(cases)
        message = "Added \(cases.count) case(s) to proposed-cases.json (\(total) in all)."
        NSWorkspace.shared.activateFileViewerSelecting([store.proposedCasesURL])
    }

    var summaryLine: String {
        guard let s = selected else { return "" }
        let x = LabStore.summary(findings, misses: s.misses.count)
        return "\(findings.count) detections \u{00B7} \(x.correct) correct \u{00B7} \(x.wrong) wrong \u{00B7} \(x.falseAlarms) false alarms \u{00B7} \(x.missed) missed \u{00B7} \(x.unreviewed) to review"
    }

    /// The lines to paste into Claude's settings to connect the Lab.
    var connectorConfig: String {
        """
        {
          "mcpServers": {
            "wordcue-lab": {
              "command": "/PATH/TO/word-cue/app/WordCueKit/.build/release/wordcue-lab-mcp"
            }
          }
        }
        """
    }
}
