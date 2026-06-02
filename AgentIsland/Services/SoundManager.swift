import AVFoundation
import SwiftUI

/// Programmatic 8-bit synth sound effects — zero resource dependencies.
/// Renders tones to an in-memory WAV and plays them with `AVAudioPlayer`, whose
/// `play()` returns a Bool instead of throwing an Objective-C exception. A bad
/// audio-device state (unplugged headphones, Bluetooth switch, wake-from-sleep)
/// therefore degrades to silence and can never abort the whole app — unlike
/// `AVAudioPlayerNode.play()`, which raises an NSException that Swift can't catch.
final class SoundManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundManager()

    @AppStorage("soundEnabled") var soundEnabled = true

    private let sampleRate: Double = 44100

    /// Players are retained until playback finishes — otherwise they're freed
    /// mid-sound and you hear nothing.
    private var activePlayers: [AVAudioPlayer] = []
    private let lock = NSLock()

    private override init() { super.init() }

    // MARK: - Sound Events

    func playPermission() {
        playTone(frequencies: [880, 0, 1100], durations: [0.08, 0.04, 0.08], waveform: .square)
    }

    func playSuccess() {
        playTone(frequencies: [523, 659, 784], durations: [0.08, 0.08, 0.12], waveform: .square)
    }

    func playError() {
        playTone(frequencies: [330, 220], durations: [0.12, 0.18], waveform: .square)
    }

    func playSessionStart() {
        playTone(frequencies: [440, 660, 880], durations: [0.06, 0.06, 0.1], waveform: .sine)
    }

    func playQuestion() {
        playTone(frequencies: [440, 554, 660], durations: [0.08, 0.08, 0.1], waveform: .sine)
    }

    // MARK: - Synth Engine

    private enum Waveform { case sine, square }

    private func playTone(frequencies: [Double], durations: [Double], waveform: Waveform) {
        guard soundEnabled else { return }

        let samples = generateSamples(frequencies: frequencies, durations: durations, waveform: waveform)
        guard !samples.isEmpty, let data = wavData(from: samples) else { return }

        // try? + Bool return = no uncaught ObjC exception path → can't crash the app.
        guard let player = try? AVAudioPlayer(data: data) else {
            print("[SoundManager] Failed to create player")
            return
        }
        player.delegate = self
        player.prepareToPlay()

        lock.lock()
        activePlayers.append(player)
        lock.unlock()

        if !player.play() {
            print("[SoundManager] play() returned false — degrading to silence")
            removePlayer(player)
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        removePlayer(player)
    }

    private func removePlayer(_ player: AVAudioPlayer) {
        lock.lock()
        activePlayers.removeAll { $0 === player }
        lock.unlock()
    }

    // MARK: - Rendering

    private func generateSamples(frequencies: [Double], durations: [Double], waveform: Waveform) -> [Float] {
        var samples: [Float] = []
        let volume: Float = 0.08

        for (freq, dur) in zip(frequencies, durations) {
            let count = Int(sampleRate * dur)
            for i in 0..<count {
                let t = Double(i) / sampleRate
                let fadeOut = Float(max(0, 1.0 - t / dur * 0.3))
                let sample: Float

                if freq == 0 {
                    sample = 0
                } else {
                    switch waveform {
                    case .sine:
                        sample = Float(sin(2 * .pi * freq * t)) * volume * fadeOut
                    case .square:
                        let s = sin(2 * .pi * freq * t)
                        sample = (s >= 0 ? volume : -volume) * fadeOut
                    }
                }
                samples.append(sample)
            }
        }
        return samples
    }

    /// Wrap 16-bit PCM mono samples in a minimal WAV container for `AVAudioPlayer(data:)`.
    private func wavData(from samples: [Float]) -> Data? {
        let bitsPerSample = 16
        let channels = 1
        let bytesPerSample = bitsPerSample / 8
        let dataSize = samples.count * bytesPerSample
        let byteRate = Int(sampleRate) * channels * bytesPerSample
        let blockAlign = channels * bytesPerSample

        var data = Data(capacity: 44 + dataSize)
        func putString(_ s: String) { data.append(contentsOf: s.utf8) }
        func putU32(_ v: UInt32) { var le = v.littleEndian; withUnsafeBytes(of: &le) { data.append(contentsOf: $0) } }
        func putU16(_ v: UInt16) { var le = v.littleEndian; withUnsafeBytes(of: &le) { data.append(contentsOf: $0) } }

        // RIFF header
        putString("RIFF")
        putU32(UInt32(36 + dataSize))
        putString("WAVE")
        // fmt chunk
        putString("fmt ")
        putU32(16)                          // PCM fmt chunk size
        putU16(1)                           // audio format = PCM
        putU16(UInt16(channels))
        putU32(UInt32(sampleRate))
        putU32(UInt32(byteRate))
        putU16(UInt16(blockAlign))
        putU16(UInt16(bitsPerSample))
        // data chunk
        putString("data")
        putU32(UInt32(dataSize))
        for s in samples {
            let clamped = max(-1.0, min(1.0, s))
            let intSample = Int16(clamped * Float(Int16.max))
            putU16(UInt16(bitPattern: intSample))
        }
        return data
    }
}
