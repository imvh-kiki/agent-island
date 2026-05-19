import AVFoundation
import SwiftUI

/// Programmatic 8-bit synth sound effects — zero resource dependencies.
/// Uses a single shared AVAudioEngine that auto-stops after idle.
final class SoundManager {
    static let shared = SoundManager()

    @AppStorage("soundEnabled") var soundEnabled = true

    private let sampleRate: Double = 44100
    private let format: AVAudioFormat

    // Shared engine + player — lazily created, auto-stopped after idle
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var idleTimer: DispatchWorkItem?
    private let engineLock = NSLock()

    private init() {
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            fatalError("[SoundManager] Failed to create audio format — this should never happen")
        }
        format = fmt
    }

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

        engineLock.lock()
        let (engine, player) = ensureEngine()
        engineLock.unlock()

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channelData = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for i in 0..<samples.count {
            channelData[i] = samples[i]
        }

        guard engine.isRunning else { return }

        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }

        scheduleIdleShutdown()
    }

    /// Returns the shared engine + player, creating them if needed.
    private func ensureEngine() -> (AVAudioEngine, AVAudioPlayerNode) {
        if let engine, let playerNode, engine.isRunning {
            return (engine, playerNode)
        }

        // Tear down old engine if it exists but isn't running
        self.playerNode = nil
        self.engine = nil

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            print("[SoundManager] Engine start error: \(error)")
        }

        self.engine = engine
        self.playerNode = player
        return (engine, player)
    }

    /// Stop the engine after 5 seconds of inactivity to free resources.
    private func scheduleIdleShutdown() {
        idleTimer?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.engineLock.lock()
            self.playerNode?.stop()
            self.engine?.stop()
            self.playerNode = nil
            self.engine = nil
            self.engineLock.unlock()
        }
        idleTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

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
}
