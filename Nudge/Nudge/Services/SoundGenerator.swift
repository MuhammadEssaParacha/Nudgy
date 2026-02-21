//
//  SoundGenerator.swift
//  Nudge
//
//  Generates placeholder .caf sound files programmatically using AVFoundation.
//  These are used when bundled .caf files are missing (dev/testing).
//  For production, replace with professionally designed sounds.
//

import AVFoundation
import Foundation
import os

/// Generates rich synthesized sounds for the Antarctic sound palette.
/// Uses additive synthesis with harmonics, ADSR envelopes, and spatial effects.
/// Sounds are designed to feel icy, crystalline, and warm — matching the Antarctic theme.
///
/// Call `SoundGenerator.generateMissingSounds()` on first launch to create
/// audio files. Replace with professionally designed .caf files for App Store.
enum SoundGenerator {
    
    private static let sampleRate: Double = 44100
    
    /// Bump this version when sound synthesis changes — forces regeneration
    private static let soundVersion = 2
    
    // MARK: - Public
    
    /// Check for missing sound files and generate them in the app's
    /// support directory. Returns the directory URL for SoundService to load from.
    @discardableResult
    static func generateMissingSounds() -> URL {
        let dir = supportDirectory()
        
        // Version check — regenerate all if synthesis changed
        let versionFile = dir.appendingPathComponent(".sound-version")
        let currentVersion = (try? String(contentsOf: versionFile, encoding: .utf8))
            .flatMap { Int($0) } ?? 0
        if currentVersion < soundVersion {
            // Clear old sounds
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.pathExtension == "caf" {
                try? FileManager.default.removeItem(at: file)
            }
            try? String(soundVersion).write(to: versionFile, atomically: true, encoding: .utf8)
        }
        
        let sounds: [(String, () -> [Float])] = [
            ("brain-dump-start", { synthesizeIceBubble() }),
            ("task-done",        { synthesizeIceChime() }),
            ("all-clear",        { synthesizeWarmChord() }),
            ("nudge-knock",      { synthesizeIceKnock() }),
            ("tab-switch",       { synthesizeIceTap() }),
            ("snooze",           { synthesizeSnoozeCrystal() }),
            ("fish-caught",      { synthesizeFishBlub() }),
            ("mic-start",        { synthesizeActivationTone() }),
            ("send-message",     { synthesizeWhooshUp() }),
        ]
        
        for (name, generator) in sounds {
            let fileURL = dir.appendingPathComponent("\(name).caf")
            if FileManager.default.fileExists(atPath: fileURL.path) { continue }
            
            let samples = generator()
            writeSamplesToCAF(samples, url: fileURL)
        }
        
        return dir
    }
    
    // MARK: - ADSR Envelope
    
    /// Attack-Decay-Sustain-Release envelope for natural-sounding tones
    private static func adsr(
        t: Float, duration: Float,
        attack: Float = 0.01, decay: Float = 0.05,
        sustain: Float = 0.7, release: Float = 0.1
    ) -> Float {
        let releaseStart = duration - release
        if t < attack {
            return t / attack  // Attack: 0→1
        } else if t < attack + decay {
            let decayProgress = (t - attack) / decay
            return 1.0 - (1.0 - sustain) * decayProgress  // Decay: 1→sustain
        } else if t < releaseStart {
            return sustain  // Sustain
        } else {
            let releaseProgress = (t - releaseStart) / release
            return sustain * max(0, 1.0 - releaseProgress)  // Release: sustain→0
        }
    }
    
    /// Exponential decay envelope — natural for plucked/struck tones
    private static func expDecay(t: Float, duration: Float, rate: Float = 5.0) -> Float {
        let progress = t / duration
        return max(0, exp(-rate * progress))
    }
    
    // MARK: - Synthesis: Antarctic Sound Palette
    
    /// Crystalline ice bubble — bright pop with harmonic shimmer (0.25s)
    /// Used for brain dump start — feels like an ice crystal forming
    private static func synthesizeIceBubble() -> [Float] {
        let duration: Float = 0.25
        let count = Int(Double(duration) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        
        // Base tone: bright A5 with quick pitch sweep (bubble rising)
        let baseFreq: Float = 880
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            let pitchSweep: Float = 1.0 + 0.15 * expDecay(t: t, duration: duration, rate: 12.0)
            let freq = baseFreq * pitchSweep
            let env = expDecay(t: t, duration: duration, rate: 8.0)
            
            // Fundamental + 2nd harmonic (octave) + 3rd (makes it sparkly)
            let fundamental = sinf(2 * .pi * freq * t) * 0.5
            let harmonic2 = sinf(2 * .pi * freq * 2 * t) * 0.25
            let harmonic3 = sinf(2 * .pi * freq * 3 * t) * 0.1
            
            samples[i] = (fundamental + harmonic2 + harmonic3) * env * 0.35
        }
        return samples
    }
    
    /// Ascending ice chime — C5→E5→G5 with crystalline overtones (0.4s)
    /// Used for task completion — feels like ice crystals ascending
    private static func synthesizeIceChime() -> [Float] {
        let duration: Float = 0.4
        let count = Int(Double(duration) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        
        // Three notes staggered: C5→E5→G5 (major triad ascending)
        let notes: [(freq: Float, onset: Float)] = [
            (523.25, 0.0),    // C5
            (659.25, 0.08),   // E5
            (783.99, 0.16),   // G5
        ]
        
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            var sum: Float = 0
            
            for note in notes {
                guard t >= note.onset else { continue }
                let localT = t - note.onset
                let noteDuration = duration - note.onset
                let env = expDecay(t: localT, duration: noteDuration, rate: 6.0)
                
                // Rich tone: fundamental + soft octave + sparkle at 3rd harmonic
                let f = note.freq
                sum += sinf(2 * .pi * f * t) * env * 0.35
                sum += sinf(2 * .pi * f * 2 * t) * env * 0.12  // octave shimmer
                sum += sinf(2 * .pi * f * 3 * t) * env * 0.05  // sparkle
            }
            
            samples[i] = sum * 0.4
        }
        return samples
    }
    
    /// Warm harmonic chord with shimmer — C4-E4-G4-C5 (0.6s)
    /// Used for all-clear — triumphant but gentle
    private static func synthesizeWarmChord() -> [Float] {
        let duration: Float = 0.6
        let count = Int(Double(duration) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        
        let freqs: [Float] = [261.63, 329.63, 392.0, 523.25]  // C4, E4, G4, C5
        
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            let env = adsr(t: t, duration: duration, attack: 0.02, decay: 0.08, sustain: 0.6, release: 0.2)
            
            var sum: Float = 0
            for (idx, f) in freqs.enumerated() {
                // Each note slightly detuned for warmth (chorus effect)
                let detune: Float = 1.0 + Float(idx) * 0.001
                sum += sinf(2 * .pi * f * detune * t) * 0.3
                sum += sinf(2 * .pi * f * 2 * detune * t) * 0.08  // soft octave
            }
            
            // Add a high shimmer sweep
            let shimmerFreq: Float = 2093.0  // C7
            let shimmerEnv = expDecay(t: t, duration: duration, rate: 10.0)
            sum += sinf(2 * .pi * shimmerFreq * t) * shimmerEnv * 0.06
            
            samples[i] = (sum / Float(freqs.count)) * env * 0.35
        }
        return samples
    }
    
    /// Soft double knock on ice — resonant thuds with icy overtone (0.5s)
    /// Used for notifications — authoritative but gentle
    private static func synthesizeIceKnock() -> [Float] {
        let duration: Float = 0.5
        let count = Int(Double(duration) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        
        let knocks: [(onset: Float, duration: Float)] = [
            (0.0, 0.08),
            (0.15, 0.08),
        ]
        
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            
            for knock in knocks {
                guard t >= knock.onset && t < knock.onset + knock.duration + 0.1 else { continue }
                let localT = t - knock.onset
                let env = expDecay(t: localT, duration: knock.duration + 0.1, rate: 20.0)
                
                // Deep thud + mid resonance + icy overtone
                let thud = sinf(2 * .pi * 100 * t) * env * 0.5
                let resonance = sinf(2 * .pi * 280 * t) * env * 0.25
                let icy = sinf(2 * .pi * 1200 * t) * env * env * 0.08  // high click, decays fast
                
                samples[i] += (thud + resonance + icy) * 0.4
            }
        }
        return samples
    }
    
    /// Subtle ice tap — single crystalline click (0.12s)
    /// Used for tab switching — barely there, just enough feedback
    private static func synthesizeIceTap() -> [Float] {
        let duration: Float = 0.12
        let count = Int(Double(duration) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            let env = expDecay(t: t, duration: duration, rate: 30.0)
            
            // High crystalline click
            let click = sinf(2 * .pi * 2400 * t) * 0.4
            let body = sinf(2 * .pi * 800 * t) * 0.3
            
            samples[i] = (click + body) * env * 0.2
        }
        return samples
    }
    
    /// Descending crystal — soft going-to-sleep tone (0.35s)
    /// Used for snooze — feels like gently freezing
    private static func synthesizeSnoozeCrystal() -> [Float] {
        let duration: Float = 0.35
        let count = Int(Double(duration) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        
        // Descending: G5 → D5 → C5
        let startFreq: Float = 783.99  // G5
        let endFreq: Float = 523.25    // C5
        
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            let progress = t / duration
            let freq = startFreq + (endFreq - startFreq) * progress  // Linear descent
            let env = adsr(t: t, duration: duration, attack: 0.01, decay: 0.04, sustain: 0.5, release: 0.15)
            
            let fundamental = sinf(2 * .pi * freq * t) * 0.4
            let octave = sinf(2 * .pi * freq * 2 * t) * 0.1
            
            samples[i] = (fundamental + octave) * env * 0.3
        }
        return samples
    }
    
    /// Underwater blub + sparkle (0.4s)
    /// Used for fish caught — playful underwater pop
    private static func synthesizeFishBlub() -> [Float] {
        let duration: Float = 0.4
        let count = Int(Double(duration) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            
            // Blub: low tone with upward pitch bend
            let blubFreq: Float = 200 + 300 * expDecay(t: t, duration: 0.15, rate: 8.0)
            let blubEnv = expDecay(t: t, duration: 0.2, rate: 10.0)
            let blub = sinf(2 * .pi * blubFreq * t) * blubEnv * 0.4
            
            // Sparkle: delayed high harmonics
            let sparkleOnset: Float = 0.1
            var sparkle: Float = 0
            if t > sparkleOnset {
                let st = t - sparkleOnset
                let sEnv = expDecay(t: st, duration: duration - sparkleOnset, rate: 8.0)
                sparkle = sinf(2 * .pi * 1568 * t) * sEnv * 0.15  // G6
                sparkle += sinf(2 * .pi * 2093 * t) * sEnv * 0.08  // C7
            }
            
            samples[i] = (blub + sparkle) * 0.35
        }
        return samples
    }
    
    /// Gentle activation tone — soft rising ping (0.15s)
    /// Used for mic start — inviting, not startling
    private static func synthesizeActivationTone() -> [Float] {
        let duration: Float = 0.15
        let count = Int(Double(duration) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            // Quick rising pitch
            let freq: Float = 600 + 400 * (t / duration)
            let env = adsr(t: t, duration: duration, attack: 0.005, decay: 0.02, sustain: 0.6, release: 0.06)
            
            samples[i] = sinf(2 * .pi * freq * t) * env * 0.25
        }
        return samples
    }
    
    /// Soft whoosh-up — filtered noise sweep (0.2s)
    /// Used for send message — feels like text flying away
    private static func synthesizeWhooshUp() -> [Float] {
        let duration: Float = 0.2
        let count = Int(Double(duration) * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        
        // Seeded RNG for deterministic output
        var rng: UInt32 = 42
        
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            let env = adsr(t: t, duration: duration, attack: 0.01, decay: 0.03, sustain: 0.4, release: 0.08)
            
            // Simple filtered noise: rising center frequency
            let centerFreq = 400 + 2000 * (t / duration)
            
            // Pseudo-random noise
            rng = rng &* 1664525 &+ 1013904223
            let noise = Float(Int32(bitPattern: rng)) / Float(Int32.max)
            
            // Bandpass approximation: modulate noise with sine at center freq
            let carrier = sinf(2 * .pi * centerFreq * t)
            let filtered = noise * carrier * 0.5
            
            // Add a soft tonal element
            let tone = sinf(2 * .pi * 700 * t) * 0.2
            
            samples[i] = (filtered + tone) * env * 0.25
        }
        return samples
    }
    
    // MARK: - File I/O
    
    private static func supportDirectory() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NudgeSounds")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    /// Write raw float samples to a .caf file using AVAudioFile
    private static func writeSamplesToCAF(_ samples: [Float], url: URL) {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { return }
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else { return }
        
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<samples.count {
                channelData[i] = samples[i]
            }
        }
        
        do {
            let file = try AVAudioFile(
                forWriting: url,
                settings: format.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
            try file.write(from: buffer)
        } catch {
            Log.services.warning("SoundGenerator: Failed to write \(url.lastPathComponent): \(error, privacy: .public)")
        }
    }
}
