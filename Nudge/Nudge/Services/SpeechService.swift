//
//  SpeechService.swift
//  Nudge
//
//  SFSpeechRecognizer wrapper — on-device speech-to-text.
//  Capped at 55 seconds (Apple's limit workaround).
//

import Speech
import AVFoundation
import os.log

private let speechLog = Logger(subsystem: "com.essaparacha.nudge", category: "SpeechService")

/// Wraps Apple's SFSpeechRecognizer for on-device voice recognition.
@MainActor @Observable
final class SpeechService {
    
    // MARK: - State
    
    enum SpeechState: Equatable {
        case idle
        case requesting           // Requesting permission
        case recording            // Actively recording
        case processing           // Stopped recording, finalizing transcript
        case silenceDetected(String) // User stopped talking — transcript ready for auto-send
        case emptySilence         // Long silence with no speech — conversation should end
        case finished(String)     // Final transcript
        case error(String)        // Error message
    }
    
    private(set) var state: SpeechState = .idle
    private(set) var liveTranscript: String = ""
    private(set) var elapsedTime: TimeInterval = 0
    
    /// Audio level (0.0 – 1.0) for waveform visualization
    private(set) var audioLevel: Float = 0
    
    /// Recent audio level samples for waveform bars
    private(set) var waveformSamples: [Float] = Array(repeating: 0, count: 20)
    
    /// Whether silence-based auto-send is enabled (conversation mode)
    var silenceAutoSendEnabled = false
    
    /// Duration of continuous silence before triggering auto-send (seconds)
    private var silenceThreshold: TimeInterval = 1.8
    
    /// Base silence threshold (before adaptive adjustment)
    private let baseSilenceThreshold: TimeInterval = 1.8
    
    /// Audio level below which counts as "silence"
    private let silenceLevelThreshold: Float = 0.005
    
    /// Ambient noise level measured before recording (0.0 - 1.0)
    private(set) var ambientNoiseLevel: Float = 0
    
    /// Whether the environment is noisy
    private(set) var isNoisyEnvironment = false
    
    /// Low-confidence words from last transcription
    private(set) var lowConfidenceSegments: [String] = []
    
    /// Last time the transcript changed (used for silence detection — more reliable than audio levels)
    private var lastTranscriptChangeTime: Date?
    
    /// Previous transcript snapshot for change detection
    private var previousTranscript: String = ""
    
    /// Last time speech (above silence threshold) was detected (backup for audio-level detection)
    private var lastSpeechTime: Date?
    
    /// True while we're in the process of an auto-send teardown — suppresses the
    /// recognition-task cancellation error that would otherwise overwrite .silenceDetected
    private var isTearingDownForAutoSend = false
    
    /// Minimum transcript length before silence triggers send (avoid accidental sends)
    private let minimumTranscriptLength = 2
    
    /// Duration of silence with NO transcript before conversation should end
    private let emptysilenceEndThreshold: TimeInterval = 8.0
    
    /// Number of consecutive recording attempts (for retry logic)
    private var recordingAttempt = 0
    private let maxRecordingRetries = 2
    
    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }
    
    var remainingTime: TimeInterval {
        max(0, RecordingConfig.maxDuration - elapsedTime)
    }
    
    var showCountdown: Bool {
        remainingTime <= RecordingConfig.countdownThreshold && isRecording
    }
    
    // MARK: - Private
    
    private let speechRecognizer: SFSpeechRecognizer?  // nil if locale unsupported
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var timer: Timer?
    private var tapInstalled = false
    
    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    }
    
    // MARK: - Permission
    
    func requestPermission() async -> Bool {
        // Speech recognition permission
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        guard speechAuthorized else {
            speechLog.error("Speech recognition not authorized")
            state = .error(String(localized: "Speech recognition not authorized. Enable in Settings."))
            return false
        }
        
        // Microphone permission
        let micAuthorized = await AVAudioApplication.requestRecordPermission()
        
        guard micAuthorized else {
            speechLog.error("Microphone not authorized")
            state = .error(String(localized: "Microphone access required. Enable in Settings."))
            return false
        }
        
        return true
    }
    
    // MARK: - Ambient Noise Detection
    
    /// Sample ambient audio for 0.5s before recording to calibrate.
    /// Returns the measured noise level.
    func measureAmbientNoise() async -> Float {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            speechLog.warning("Ambient noise measurement failed: \(error.localizedDescription)")
            return 0
        }
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { return 0 }
        
        var samples: [Float] = []
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength { sum += abs(channelData[i]) }
            let avg = sum / Float(max(frameLength, 1))
            samples.append(min(avg * 10, 1.0))
        }
        
        engine.prepare()
        do {
            try engine.start()
            try await Task.sleep(for: .milliseconds(500))
            engine.stop()
            inputNode.removeTap(onBus: 0)
        } catch {
            speechLog.warning("Ambient noise engine error: \(error.localizedDescription)")
            engine.stop()
            inputNode.removeTap(onBus: 0)
            return 0
        }
        
        let level = samples.isEmpty ? 0 : samples.reduce(0, +) / Float(samples.count)
        ambientNoiseLevel = level
        isNoisyEnvironment = level > 0.05
        
        // Adaptive silence threshold based on ambient noise
        if level > 0.1 {
            silenceThreshold = 2.5  // Very noisy — longer silence before auto-send
        } else if level > 0.05 {
            silenceThreshold = 2.0  // Moderately noisy
        } else {
            silenceThreshold = baseSilenceThreshold  // Quiet — default
        }
        
        speechLog.info("Ambient noise: \(String(format: "%.3f", level)), threshold: \(self.silenceThreshold)s, noisy: \(self.isNoisyEnvironment)")
        return level
    }
    
    // MARK: - Start Recording
    
    func startRecording() throws {
        speechLog.info("startRecording: begin (attempt \(self.recordingAttempt))")
        
        // Fully tear down any previous recording
        tearDownAudioPipeline()
        
        // Check speech recognizer availability
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            speechLog.error("startRecording: speech recognizer unavailable")
            state = .error("Speech recognizer unavailable")
            return
        }
        speechLog.info("startRecording: recognizer OK, locale=\(speechRecognizer.locale.identifier)")
        
        // Stop any TTS playback FIRST — and give it a moment to release the audio session
        NudgyVoiceOutput.shared.stop()
        
        // CRITICAL: Deactivate the audio session first before reconfiguring.
        // On real devices, flipping categories without deactivating first can leave
        // the audio hardware in a bad state.
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        
        // Configure audio session for recording
        // Use .default mode — .voiceChat applies AGC/echo cancellation that can
        // interfere with speech recognition on some devices
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            speechLog.info("startRecording: audio session configured (category=\(audioSession.category.rawValue), mode=\(audioSession.mode.rawValue))")
        } catch {
            speechLog.error("startRecording: audio session config FAILED: \(error.localizedDescription)")
            state = .error("Audio setup failed: \(error.localizedDescription)")
            return
        }
        
        // Create a FRESH audio engine every time.
        // Reusing AVAudioEngine after stopping can leave the input node in a
        // stale state on real devices (format becomes invalid, taps fail).
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            state = .error("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Guard against invalid audio format (0 channels / 0 sample rate)
        guard recordingFormat.channelCount > 0, recordingFormat.sampleRate > 0 else {
            speechLog.error("startRecording: invalid format ch=\(recordingFormat.channelCount) sr=\(recordingFormat.sampleRate)")
            state = .error("Microphone format invalid (ch=\(recordingFormat.channelCount) sr=\(recordingFormat.sampleRate))")
            return
        }
        speechLog.info("startRecording: format ch=\(recordingFormat.channelCount) sr=\(recordingFormat.sampleRate)")
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Extract audio level for waveform visualization
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += abs(channelData[i])
            }
            let average = sum / Float(max(frameLength, 1))
            let normalized = min(average * 10, 1.0)
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.audioLevel = normalized
                self.waveformSamples.removeFirst()
                self.waveformSamples.append(normalized)
                
                if normalized > self.silenceLevelThreshold {
                    self.lastSpeechTime = Date()
                }
            }
        }
        tapInstalled = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                if let result {
                    let newTranscript = result.bestTranscription.formattedString
                    
                    // Track when the transcript actually changes (for silence detection)
                    if newTranscript != self.previousTranscript {
                        self.previousTranscript = newTranscript
                        self.lastTranscriptChangeTime = Date()
                    }
                    
                    // Confidence-based filtering: identify low-confidence segments
                    let segments = result.bestTranscription.segments
                    self.lowConfidenceSegments = segments
                        .filter { $0.confidence > 0 && $0.confidence < 0.3 }
                        .map { $0.substring }
                    
                    self.liveTranscript = newTranscript
                    if result.isFinal {
                        speechLog.info("Recognition result isFinal: \(self.liveTranscript.prefix(60))")
                        self.state = .finished(self.liveTranscript)
                    }
                }
                
                if let error {
                    // Don't overwrite terminal states
                    if case .finished = self.state { return }
                    if case .silenceDetected = self.state { return }
                    if case .emptySilence = self.state { return }
                    
                    // If we're tearing down for auto-send, the cancel error is expected — ignore it
                    if self.isTearingDownForAutoSend {
                        speechLog.info("Suppressing error during auto-send teardown")
                        return
                    }
                    
                    let nsError = error as NSError
                    speechLog.error("Recognition error: \(nsError.domain) code=\(nsError.code) \(error.localizedDescription)")
                    
                    // Error code 1101 = "no speech detected" — not a real error
                    // Error code 216 = request was canceled — normal during cleanup
                    if nsError.code == 1101 || nsError.code == 216 {
                        speechLog.info("Benign recognition error (code \(nsError.code)), treating as idle")
                        if !self.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            self.state = .finished(self.liveTranscript)
                        }
                        return
                    }
                    
                    // If we already have some transcript, treat as success
                    if !self.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.state = .finished(self.liveTranscript)
                    } else {
                        self.state = .error(error.localizedDescription)
                    }
                    self.tearDownAudioPipeline()
                }
            }
        }
        
        speechLog.info("startRecording: starting audio engine...")
        engine.prepare()
        do {
            try engine.start()
        } catch {
            speechLog.error("startRecording: engine.start() FAILED: \(error.localizedDescription)")
            tearDownAudioPipeline()
            state = .error("Mic engine failed: \(error.localizedDescription)")
            return
        }
        speechLog.info("startRecording: ✅ engine running")
        
        state = .recording
        elapsedTime = 0
        liveTranscript = ""
        audioLevel = 0
        waveformSamples = Array(repeating: 0, count: 20)
        lastSpeechTime = nil
        lastTranscriptChangeTime = nil
        previousTranscript = ""
        recordingAttempt = 0 // Reset retry counter on success
        
        // Start countdown timer
        startTimer()
    }
    
    // MARK: - Stop Recording
    
    /// Stop recording for silence-based auto-send (preserves .silenceDetected state)
    func stopRecordingForAutoSend() {
        isTearingDownForAutoSend = true
        tearDownAudioPipeline()
        // Reset after a tick — by then the cancellation error has already been suppressed
        DispatchQueue.main.async { [weak self] in
            self?.isTearingDownForAutoSend = false
        }
    }
    
    func stopRecording() {
        let wasRecording: Bool
        if case .recording = state { wasRecording = true } else { wasRecording = false }
        
        tearDownAudioPipeline()
        
        if wasRecording {
            if liveTranscript.isEmpty {
                state = .idle
            } else {
                state = .finished(liveTranscript)
            }
        }
    }
    
    /// Fully tear down the audio pipeline — engine, tap, request, task, session.
    /// Creates a clean slate so the next startRecording() works reliably.
    private func tearDownAudioPipeline() {
        timer?.invalidate()
        timer = nil
        
        // 1. End the recognition request (tells the task we're done sending audio)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // 2. Cancel the recognition task (not finish — cancel is more aggressive and reliable)
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 3. Stop the engine and remove tap
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            if tapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
        }
        
        // 4. Dispose of the engine entirely — next recording creates a fresh one
        audioEngine = nil
        
        lastSpeechTime = nil
        lastTranscriptChangeTime = nil
        previousTranscript = ""
        
        // 5. Restore audio session for TTS playback
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            speechLog.warning("tearDown: audio session restore failed: \(error.localizedDescription)")
        }
    }
    
    /// Reset to idle
    func reset() {
        tearDownAudioPipeline()
        state = .idle
        liveTranscript = ""
        elapsedTime = 0
        audioLevel = 0
        waveformSamples = Array(repeating: 0, count: 20)
    }
    
    // MARK: - Retry
    
    /// Attempt to start recording with automatic retry on failure
    func startRecordingWithRetry() async throws {
        do {
            try startRecording()
        } catch {
            recordingAttempt += 1
            speechLog.warning("startRecording failed (attempt \(self.recordingAttempt)/\(self.maxRecordingRetries)): \(error.localizedDescription)")
            
            if recordingAttempt <= maxRecordingRetries {
                // Tear down completely, wait a beat, then retry
                tearDownAudioPipeline()
                try await Task.sleep(for: .milliseconds(500))
                speechLog.info("Retrying startRecording...")
                try startRecording()
            } else {
                recordingAttempt = 0
                throw error
            }
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.elapsedTime += 0.3
                
                // Auto-stop at max duration
                if self.elapsedTime >= RecordingConfig.maxDuration {
                    self.stopRecording()
                    return
                }
                
                // Silence detection for conversation mode
                // Use transcript-change-based detection (more reliable than audio levels on real devices)
                if self.silenceAutoSendEnabled,
                   !self.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   self.liveTranscript.count >= self.minimumTranscriptLength {
                    
                    // Use transcript change time (primary) or audio level time (fallback)
                    let lastActivity = self.lastTranscriptChangeTime ?? self.lastSpeechTime
                    if let lastActivity {
                        let silenceDuration = Date().timeIntervalSince(lastActivity)
                        if silenceDuration >= self.silenceThreshold {
                            speechLog.info("Silence detected after \(String(format: "%.1f", silenceDuration))s — auto-sending transcript: \(self.liveTranscript.prefix(40))")
                            let transcript = self.liveTranscript
                            self.state = .silenceDetected(transcript)
                            self.stopRecordingForAutoSend()
                        }
                    }
                }
                
                // Empty silence detection — user hasn't said anything for a while
                if self.silenceAutoSendEnabled,
                   self.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   self.elapsedTime >= self.emptysilenceEndThreshold {
                    speechLog.info("Empty silence for \(String(format: "%.1f", self.elapsedTime))s — ending conversation")
                    self.state = .emptySilence
                    self.stopRecordingForAutoSend()
                }
            }
        }
    }
}
