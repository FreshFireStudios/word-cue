// UNTESTED: written without Xcode and never run against real hardware.
// Captures audio from the chosen input (the soundboard's USB/audio interface
// feed, or the built-in mic) and hands raw buffers to whoever is listening.
import AVFoundation
import CoreAudio

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
}

enum AudioInputError: LocalizedError {
    case noPermission
    case noInput

    var errorDescription: String? {
        switch self {
        case .noPermission: return "Word Cue needs microphone access. Turn it on in System Settings > Privacy & Security > Microphone."
        case .noInput: return "No audio input was found. Check that the soundboard's audio interface is plugged in."
        }
    }
}

final class AudioInput {
    private let engine = AVAudioEngine()
    private(set) var isRunning = false

    /// Every device that can record: built-in mic, USB interfaces, etc.
    static func inputDevices() -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            guard inputChannelCount(id) > 0,
                  let name = stringProperty(id, kAudioObjectPropertyName),
                  let uid = stringProperty(id, kAudioDevicePropertyDeviceUID) else { return nil }
            return AudioDevice(id: id, uid: uid, name: name)
        }
    }

    private static func inputChannelCount(_ id: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                                 mScope: kAudioDevicePropertyScopeInput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func stringProperty(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    struct Options {
        var deviceUID = ""          // empty = whatever macOS has as the default input
        var channel = 1             // 1-based; 0 = mix every channel together
        var gainDB: Double = 6      // boosts a quiet feed
        var gateDB: Double = -45    // anything quieter than this is treated as silence
        var bufferFrames: UInt32 = 1024
    }

    /// Starts capturing. `onBuffer` is called on an audio thread, many times a
    /// second, with one-channel audio, its loudness (0...1) and whether it is above the noise gate.
    func start(_ options: Options, onBuffer: @escaping (AVAudioPCMBuffer, Float, Bool) -> Void) async throws {
        guard await Self.requestPermission() else { throw AudioInputError.noPermission }
        stop()
        let input = engine.inputNode
        if !options.deviceUID.isEmpty, let device = Self.inputDevices().first(where: { $0.uid == options.deviceUID }),
           let unit = input.audioUnit {
            var id = device.id
            AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                 &id, UInt32(MemoryLayout<AudioDeviceID>.size))
        }
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0,
              let mono = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate, channels: 1, interleaved: false)
        else { throw AudioInputError.noInput }
        let gain = Float(pow(10, options.gainDB / 20))
        // 1024 frames is about 21 ms at 48 kHz. Smaller = less delay, larger = fewer dropouts.
        input.installTap(onBus: 0, bufferSize: options.bufferFrames, format: format) { buffer, _ in
            guard let source = buffer.floatChannelData,
                  let out = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: buffer.frameLength),
                  let dest = out.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            let channels = Int(buffer.format.channelCount)
            out.frameLength = buffer.frameLength
            var sum: Float = 0
            let pick = options.channel >= 1 && options.channel <= channels ? options.channel - 1 : -1
            for i in 0..<frames {
                var v: Float = 0
                if pick >= 0 {
                    v = source[pick][i]
                } else {
                    for c in 0..<channels { v += source[c][i] }
                    v /= Float(channels)
                }
                v *= gain
                dest[i] = v
                sum += v * v
            }
            let db = 20 * log10(max((sum / Float(max(frames, 1))).squareRoot(), 0.000_01))
            let open = Double(db) > options.gateDB
            if !open { for i in 0..<frames { dest[i] = 0 } }      // below the noise gate: send silence
            onBuffer(out, max(0, min(1, (db + 50) / 50)), open)
        }
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    /// How many input channels a device has (for the channel picker).
    static func channelCount(uid: String) -> Int {
        guard let device = inputDevices().first(where: { $0.uid == uid }) else { return 2 }
        return max(1, inputChannelCount(device.id))
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }
}
