// UNTESTED: written without Xcode. Uses Apple's SpeechAnalyzer the same way
// Word Cue does, but on a recording instead of a live microphone, and keeps
// the time of each piece. VERIFY: `result.range` and `start(inputAudioFile:finishAfterFile:)`.
import AVFoundation
import Speech
import WordCueKit

enum FileTranscriber {
    enum Problem: LocalizedError {
        case unsupported
        var errorDescription: String? { "On-device speech recognition is not available for English on this Mac." }
    }

    /// Transcribes a recording on this Mac. `onSegment` is called as each piece settles.
    static func transcribe(_ url: URL, vocabulary: [String], onSegment: @escaping @Sendable (LabSegment) -> Void) async throws {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) else { throw Problem.unsupported }
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let context = AnalysisContext()
        context.contextualStrings[.general] = vocabulary
        try await analyzer.setContext(context)
        let file = try AVAudioFile(forReading: url)
        let reading = Task {
            for try await result in transcriber.results where result.isFinal {
                let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                onSegment(LabSegment(start: result.range.start.seconds, end: result.range.end.seconds, text: text))
            }
        }
        try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
        try await reading.value
    }
}
