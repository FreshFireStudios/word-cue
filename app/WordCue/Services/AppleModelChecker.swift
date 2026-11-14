// UNTESTED: written without Xcode, from Apple's FoundationModels documentation
// (LanguageModelSession, SystemLanguageModel). The @Generable/@Guide usage and
// respond(to:generating:) are marked VERIFY.
//
// "Rules + Apple Intelligence" (Settings > Scripture Detection > Detection method).
// The rules engine still finds every verse, instantly. For the matches it is
// least sure about, Apple's on-device model reads the sentence and the verse
// and says whether the preacher really means that verse. The card shows right
// away; its confidence moves up or down when the answer comes back, so this
// never adds delay. Nothing leaves the Mac.
import Foundation
import FoundationModels
import WordCueKit

@Generable
struct VerseCheck {
    @Guide(description: "true if the speaker is citing, reading, or quoting this Bible verse; false if the words only happen to look like a reference or the speaker is talking about something else")
    var refersToVerse: Bool
}

final class AppleModelChecker: @unchecked Sendable {
    /// Ready, or a sentence saying why not, for Settings.
    static var status: (ready: Bool, note: String) {
        switch SystemLanguageModel.default.availability {
        case .available:
            return (true, "Apple Intelligence is ready on this Mac.")
        case .unavailable(.deviceNotEligible):
            return (false, "This Mac can\u{2019}t run Apple Intelligence. Word Cue uses its rules only.")
        case .unavailable(.modelNotReady):
            return (false, "Apple Intelligence is still downloading. Word Cue uses its rules until it\u{2019}s ready.")
        case .unavailable:
            return (false, "Apple Intelligence is turned off or unavailable. Word Cue uses its rules only.")
        }
    }

    /// Only these get a second opinion: the rules' "maybe" band and the looser kinds.
    static func worthChecking(_ d: Detection) -> Bool {
        d.kind == .quote || d.kind == .followOn || d.confidence < 0.85
    }

    /// Returns the new confidence, or nil when the model can't help.
    func check(sentence: String, reference: String, verseText: String, confidence: Double) async -> Double? {
        guard Self.status.ready else { return nil }
        let session = LanguageModelSession(instructions: """
            You check a live sermon transcript for one thing: is the preacher citing, reading or quoting \
            a specific Bible verse? Speech-to-text mistakes are common. Answer only about the verse given.
            """)
        let prompt = """
            Transcript: "\(sentence)"
            Candidate verse: \(reference) (KJV): "\(verseText)"
            """
        do {
            let response = try await session.respond(to: prompt, generating: VerseCheck.self)      // VERIFY
            return response.content.refersToVerse ? min(0.95, confidence + 0.1) : max(0.05, confidence - 0.25)
        } catch {
            DebugLog.write("Apple Intelligence check failed: \(error.localizedDescription)")
            return nil
        }
    }
}
