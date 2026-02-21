//
//  NudgyVoiceOutput.swift
//  Nudge
//
//  Phase 11: Modular text-to-speech output.
//  Supports two backends:
//  1. AVSpeechSynthesizer (on-device, free, instant fallback)
//  2. OpenAI TTS API (higher quality, warm "echo" voice — default)
//
//  The active backend is selected via NudgyConfig.Voice.useOpenAITTS.
//  OpenAI TTS is preferred for Nudgy’s warm, Pooh-like masculine warmth.
//

import AVFoundation
import Foundation
import os

// MARK: - NudgyVoiceOutput

/// Manages Nudgy's text-to-speech voice output.
/// Supports OpenAI TTS (echo voice, default) with AVSpeechSynthesizer fallback.
@MainActor @Observable
final class NudgyVoiceOutput: NSObject {
    
    static let shared = NudgyVoiceOutput()
    
    // MARK: - State
    
    private(set) var isSpeaking = false
    
    /// Whether Nudgy's voice output is enabled. Backed by NudgyConfig.
    var isEnabled: Bool {
        get { NudgyConfig.Voice.isEnabled }
        set { NudgyConfig.Voice.isEnabled = newValue }
    }
    
    // MARK: - Private
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var pendingCleanupURL: URL?
    
    /// Queue of texts waiting to be spoken (prevents overlapping speech)
    private var speechQueue: [String] = []
    private var isProcessingQueue = false
    
    /// The preferred AVSpeech voice (fallback only).
    /// Prefers a warm male voice for Pooh-like quality.
    private var systemVoice: AVSpeechSynthesisVoice? {
        // Try to find a warm male en-US voice (Aaron, Daniel, etc.)
        let enUSVoices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("en") && $0.quality != .default
        }
        // Prefer enhanced/premium male voices by identifier keywords
        if let male = enUSVoices.first(where: { $0.identifier.lowercased().contains("aaron") }) {
            return male
        }
        if let male = enUSVoices.first(where: { $0.identifier.lowercased().contains("daniel") }) {
            return male
        }
        // Fallback to any en-US voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            return voice
        }
        return AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en")
    }
    
    // MARK: - Init
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            Log.ai.warning("NudgyVoiceOutput: Audio session config failed: \(error, privacy: .public)")
        }
    }
    
    /// Ensure audio session is ready for playback (call after STT stops)
    func prepareForPlayback() {
        configureAudioSession()
    }
    
    // MARK: - Speak
    
    /// Speak text aloud as Nudgy. Queues if already speaking.
    /// Returns true if TTS will play, false if skipped (voice disabled or empty text).
    @discardableResult
    func speak(_ text: String) -> Bool {
        guard NudgyConfig.Voice.isEnabled else {
            Log.ai.debug("NudgyVoiceOutput: Voice disabled, skipping")
            return false
        }
        
        let cleaned = cleanForSpeech(text)
        guard !cleaned.isEmpty else {
            Log.ai.debug("NudgyVoiceOutput: Text empty after cleaning, skipping")
            return false
        }
        Log.ai.debug("NudgyVoiceOutput: speak() called with: \(cleaned.prefix(80))")
        
        // If already speaking, queue it
        if isSpeaking {
            Log.ai.debug("NudgyVoiceOutput: Already speaking, queueing")
            speechQueue.append(cleaned)
            return true
        }
        
        speakNow(cleaned)
        return true
    }
    
    /// Speak a short reaction (interrupts current speech, doesn't queue)
    func speakReaction(_ text: String) {
        guard NudgyConfig.Voice.isEnabled else { return }
        let cleaned = cleanForSpeech(text)
        guard !cleaned.isEmpty else { return }
        
        // Interrupt anything playing
        stop()
        speechQueue.removeAll()
        speakNow(cleaned)
    }
    
    /// Stop speaking immediately and clear queue.
    func stop() {
        speechQueue.removeAll()
        isProcessingQueue = false
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        audioPlayer = nil
        cleanupTempFile()
        isSpeaking = false
    }
    
    // MARK: - Internal
    
    private func speakNow(_ text: String) {
        isSpeaking = true
        isProcessingQueue = true
        
        if NudgyConfig.Voice.useOpenAITTS {
            speakWithOpenAI(text)
        } else {
            speakWithSystem(text)
        }
    }
    
    /// Process the next item in the speech queue
    private func processQueue() {
        guard !speechQueue.isEmpty else {
            isProcessingQueue = false
            return
        }
        
        let next = speechQueue.removeFirst()
        speakNow(next)
    }
    
    // MARK: - System TTS (AVSpeechSynthesizer) — Fallback
    
    private func speakWithSystem(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            Log.ai.warning("NudgyVoiceOutput: Audio session setup failed: \(error, privacy: .public)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = systemVoice
        utterance.pitchMultiplier = NudgyConfig.Voice.pitchMultiplier
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * NudgyConfig.Voice.rateMultiplier
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.2
        utterance.postUtteranceDelay = 0.1
        
        Log.ai.debug("NudgyVoiceOutput: Speaking (system): \(text.prefix(60))...")
        synthesizer.speak(utterance)
    }
    
    // MARK: - OpenAI TTS (Primary — warm echo voice)
    
    private func speakWithOpenAI(_ text: String) {
        Task {
            do {
                let audioData = try await NudgyLLMService.shared.textToSpeech(
                    text: text,
                    voice: NudgyConfig.Voice.openAIVoice,
                    speed: NudgyConfig.Voice.openAISpeed
                )
                
                // Write to temp file and play
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("nudgy_speech_\(UUID().uuidString).mp3")
                try audioData.write(to: tempURL)
                self.pendingCleanupURL = tempURL
                
                // Configure audio session
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.duckOthers])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                
                let player = try AVAudioPlayer(contentsOf: tempURL)
                player.delegate = self
                self.audioPlayer = player
                
                Log.ai.debug("NudgyVoiceOutput: Speaking (OpenAI \(NudgyConfig.Voice.openAIVoice)): \(text.prefix(60))... [\(String(format: "%.1f", player.duration))s]")
                player.play()
                
            } catch {
                Log.ai.warning("OpenAI TTS failed: \(error, privacy: .public). Falling back to system TTS.")
                self.speakWithSystem(text)
            }
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanupTempFile() {
        if let url = pendingCleanupURL {
            try? FileManager.default.removeItem(at: url)
            pendingCleanupURL = nil
        }
    }
    
    private func finishedSpeaking() {
        cleanupTempFile()
        audioPlayer = nil
        
        // Process next in queue, or mark done
        if !speechQueue.isEmpty {
            processQueue()
        } else {
            isSpeaking = false
            isProcessingQueue = false
            Log.ai.debug("NudgyVoiceOutput: All speech finished")
        }
    }
    
    // MARK: - Text Cleaning
    
    private func cleanForSpeech(_ text: String) -> String {
        var cleaned = text
        
        // Remove emojis
        cleaned = cleaned.unicodeScalars.filter { scalar in
            let value = scalar.value
            if value > 0x1F000 { return false }
            if (0x2600...0x27BF).contains(value) { return false }
            if (0xFE00...0xFE0F).contains(value) { return false }
            if (0x200D...0x200D).contains(value) { return false }
            if (0x2702...0x27B0).contains(value) { return false }
            return true
        }.map { String($0) }.joined()
        
        // Remove markdown
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "*", with: "")
        cleaned = cleaned.replacingOccurrences(of: "_", with: "")
        
        // Normalize whitespace
        cleaned = cleaned.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AVSpeechSynthesizerDelegate (System TTS fallback)

extension NudgyVoiceOutput: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Log.ai.debug("NudgyVoiceOutput: didStart speaking (system)")
        Task { @MainActor in self.isSpeaking = true }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Log.ai.debug("NudgyVoiceOutput: didFinish speaking (system)")
        Task { @MainActor in self.finishedSpeaking() }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Log.ai.debug("NudgyVoiceOutput: didCancel speaking (system)")
        Task { @MainActor in
            self.cleanupTempFile()
            self.isSpeaking = false
            self.isProcessingQueue = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate (OpenAI TTS)

extension NudgyVoiceOutput: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Log.ai.debug("NudgyVoiceOutput: didFinish playing (OpenAI, success=\(flag))")
        Task { @MainActor in self.finishedSpeaking() }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Log.ai.warning("NudgyVoiceOutput: decode error: \(error?.localizedDescription ?? "unknown")")
        Task { @MainActor in self.finishedSpeaking() }
    }
}
