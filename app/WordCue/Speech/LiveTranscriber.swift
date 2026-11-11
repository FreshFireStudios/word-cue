// UNTESTED: written without Xcode. This is the part most likely to need
// fixes on the first build, because it uses Apple's newest speech API
// (SpeechAnalyzer + SpeechTranscriber, macOS 26 and later) and could only be
// checked against Apple's documentation pages, not a compiler.
// See docs/SPEECH-NOTES.md for what was confirmed and what was not.
import AVFoundation
import Speech

enum TranscriptUpdate: Sendable {
    case volatile(String)   // a guess that may still change (shown faded, searched early)
    case final(String)      // settled text
}

enum TranscriberError: LocalizedError {
    case unsupportedLocale
    case noAudioFormat

    var errorDescription: String? {
        switch self {
        case .unsupportedLocale: return "On-device speech recognition is not available for English on this Mac."
        case .noAudioFormat: return "The speech recogniser did not offer an audio format."
        }
    }
}

/// On-device speech-to-text. Audio never leaves the Mac.
final class LiveTranscriber: @unchecked Sendable {
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var converter: AVAudioConverter?
    private var analyzerFormat: AVAudioFormat?

    /// Gets the recogniser ready and starts it.
    /// - Parameter vocabulary: words to listen for especially (the book names).
    func start(locale: Locale = Locale(identifier: "en-US"), vocabulary: [String],
               onUpdate: @escaping @Sendable (TranscriptUpdate) -> Void) async throws {
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw TranscriberError.unsupportedLocale
        }
        // .volatileResults = also send early guesses. That is what makes a
        // suggestion show up before the preacher has finished the sentence.
        let transcriber = SpeechTranscriber(locale: supported,
                                            transcriptionOptions: [],
                                            reportingOptions: [.volatileResults],
                                            attributeOptions: [])
        // The language model downloads once (needs internet that one time).
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        // Teach it the words that matter. VERIFY: the `.general` tag name.
        let context = AnalysisContext()
        context.contextualStrings[.general] = vocabulary
        try await analyzer.setContext(context)

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriberError.noAudioFormat
        }
        analyzerFormat = format
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation
        self.analyzer = analyzer
        self.transcriber = transcriber

        resultsTask = Task {
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    onUpdate(result.isFinal ? .final(text) : .volatile(text))
                }
            } catch {
                onUpdate(.final(""))   // stream ended; AppModel notices listening stopped
            }
        }
        try await analyzer.start(inputSequence: stream)
    }

    /// Call from the audio thread with each captured buffer.
    func append(_ buffer: AVAudioPCMBuffer) {
        guard let analyzerFormat, let inputContinuation else { return }
        if buffer.format == analyzerFormat {
            inputContinuation.yield(AnalyzerInput(buffer: buffer))
            return
        }
        // The soundboard feed is usually 48 kHz stereo; the recogniser wants
        // its own format, so convert each buffer.
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: analyzerFormat)
        }
        guard let converter else { return }
        let ratio = analyzerFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return }
        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if error == nil, out.frameLength > 0 {
            inputContinuation.yield(AnalyzerInput(buffer: out))
        }
    }

    func stop() async {
        inputContinuation?.finish()
        inputContinuation = nil
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()
        resultsTask = nil
        analyzer = nil
        transcriber = nil
        converter = nil
    }
}
