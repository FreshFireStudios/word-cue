# Apple speech on macOS: what was checked

*Checked November 11, 2026 against Apple's documentation pages for the Speech framework. Nothing here has been compiled or run.*

## Confirmed from Apple's docs

| Item | Finding |
|---|---|
| API | `SpeechAnalyzer` with a `SpeechTranscriber` module |
| Availability | macOS 26.0 and later, so it is present on the macOS 27 minimum |
| On-device | Yes. The language model is a one-time download through `AssetInventory` |
| Early guesses | `reportingOptions: [.volatileResults]` delivers words before they are final. Word Cue searches those too, which is where most of the speed comes from |
| Results | `transcriber.results` is an async sequence of `SpeechTranscriber.Result` |
| Custom words | `AnalysisContext.contextualStrings` takes words "that should be recognized even if they are not in the system vocabulary". Word Cue passes the 66 book names |
| Audio format | `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)` |
| Feeding audio | `analyzer.start(inputSequence:)` with a stream of `AnalyzerInput` |
| Fallback | Apple points to `DictationTranscriber` for devices that cannot run `SpeechTranscriber` |

## Not confirmed

- **Latency.** Apple's pages give no numbers. Measure it on the Mac with the sermon recordings.
- The exact name of the contextual-strings tag (the code uses `.general`), and the properties of `Result` (the code uses `.text` and `.isFinal`). The doc pages I could read did not list them.
- `CaptureInputSequenceProvider`: Apple's docs describe it as reading "from an AV capture device such as a microphone" and handing audio straight to the analyzer. It could replace `AudioInput.swift` and the format conversion in `LiveTranscriber.swift`. I could not read its initializer or availability, so the app uses the well-known `AVAudioEngine` route for now.
- Anything new in macOS 27. The pages I read did not mention changes.
- Apple Intelligence (the on-device language model) is **not used**. The detector is plain rules, which is faster and testable. A Create ML tagger remains a later phase.
