// UNTESTED: written without Xcode.
// "Pause during music": Apple's built-in sound classifier (SoundAnalysis)
// listens to the same audio and says when it is mostly music, so worship
// lyrics that quote scripture do not trigger verses.
import AVFoundation
import SoundAnalysis

final class MusicDetector: NSObject, SNResultsObserving, @unchecked Sendable {
    private var analyzer: SNAudioStreamAnalyzer?
    private let queue = DispatchQueue(label: "wordcue.music")
    private var position: AVAudioFramePosition = 0
    private var musicScore = 0.0     // smoothed 0...1
    /// Called when the answer changes: true = music is playing.
    var onChange: (@Sendable (Bool) -> Void)?
    private(set) var isMusic = false

    func start(format: AVAudioFormat) {
        let analyzer = SNAudioStreamAnalyzer(format: format)
        if let request = try? SNClassifySoundRequest(classifierIdentifier: .version1) {
            request.windowDuration = CMTime(seconds: 1.5, preferredTimescale: 48_000)
            try? analyzer.add(request, withObserver: self)
        }
        self.analyzer = analyzer
        position = 0
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        queue.async { [self] in
            analyzer?.analyze(buffer, atAudioFramePosition: position)
            position += AVAudioFramePosition(buffer.frameLength)
        }
    }

    func stop() {
        queue.async { [self] in
            analyzer?.removeAllRequests()
            analyzer = nil
        }
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        // VERIFY the label names: the classifier has "music", "singing" and "speech" among its ~300 sounds.
        let music = max(result.classification(forIdentifier: "music")?.confidence ?? 0,
                        result.classification(forIdentifier: "singing")?.confidence ?? 0)
        let speech = result.classification(forIdentifier: "speech")?.confidence ?? 0
        musicScore = musicScore * 0.6 + (music > speech ? music : 0) * 0.4
        let now = isMusic ? musicScore > 0.35 : musicScore > 0.6      // slow to switch back and forth
        if now != isMusic {
            isMusic = now
            onChange?(now)
        }
    }
}
