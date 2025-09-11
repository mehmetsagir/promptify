import Foundation
import AVFoundation
import SwiftUI
import AppKit

enum VoiceRecordingMode {
    case enhancement // Voice input for prompt enhancement
    case translation // Voice input for translation
    case transcription // Simple voice to text
}

@MainActor
class VoiceRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingDuration: TimeInterval = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingStartTime: Date?
    private var currentMode: VoiceRecordingMode = .transcription
    private var previousVolume: Int = 50 // Default volume level
    private var isVolumeControlEnabled = true // Flag to enable/disable volume control
    
    // Silence detection properties
    private var hasDetectedAudio = false
    private var silenceThreshold: Float = 0.02 // Minimum audio level to consider as speech
    private var minSpeechDuration: TimeInterval = 0.3 // Minimum duration with speech to process
    
    // Animation smoothing
    private var previousAudioLevel: Float = 0.0
    private let smoothingFactor: Float = 0.4 // Balanced smoothing
    
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    override init() {
        super.init()
        // Save initial system volume
        previousVolume = getCurrentSystemVolume()
    }
    
    /// Check if audio feedback is enabled in settings
    private func isAudioFeedbackEnabled() -> Bool {
        return UserDefaults.standard.object(forKey: "enableAudioFeedback") as? Bool ?? true
    }
    
    func checkMicrophonePermission() async -> Bool {
        // Force request microphone permission
        let hasPermission = await Permission.requestMicrophonePermission()
        print("🎤 Microphone permission check result: \(hasPermission)")
        return hasPermission
    }
    
    // MARK: - System Volume Control
    
    /// Get current system volume level
    private func getCurrentSystemVolume() -> Int {
        // Use AppleScript to get current volume
        let script = "output volume of (get volume settings)"
        var error: NSDictionary?
        
        if let result = NSAppleScript(source: script)?.executeAndReturnError(&error) {
            if let volume = Int(result.stringValue ?? "") {
                return volume
            }
        }
        
        if let error = error {
            print("❌ Failed to get system volume: \(error)")
        }
        
        // Return default volume if we can't get the current one
        return 50
    }
    
    /// Set system volume level
    private func setSystemVolume(to level: Int) {
        let script = "set volume output volume \(level)"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        
        if let error = error {
            print("❌ Failed to set system volume: \(error)")
        }
    }
    
    /// Mute system volume
    private func muteSystemVolume() {
        let script = "set volume output muted true"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        
        if let error = error {
            print("❌ Failed to mute system volume: \(error)")
        }
    }
    
    /// Unmute system volume
    private func unmuteSystemVolume() {
        let script = "set volume output muted false"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        
        if let error = error {
            print("❌ Failed to unmute system volume: \(error)")
        }
    }
    
    // MARK: - Sound Playback
    
    /// Play a sound file from the Sounds directory
    private func playSound(named soundName: String) {
        // Önce doğrudan Resources klasöründe ara
        var soundURL = Bundle.main.url(forResource: soundName, withExtension: nil)
        
        // Debug: Print bundle path and sound file path
        print("Bundle path: \(Bundle.main.bundlePath)")
        print("Looking for sound file: \(soundName)")
        print("Sound file URL: \(String(describing: soundURL))")
        
        // Eğer bulunamadıysa Sounds dizininde ara
        if soundURL == nil {
            soundURL = Bundle.main.url(forResource: soundName, withExtension: nil, subdirectory: "Sounds")
            if soundURL != nil {
                print("Found sound file in Sounds directory: \(String(describing: soundURL))")
            }
        }
        
        if let url = soundURL {
            if let sound = NSSound(contentsOf: url, byReference: true) {
                print("Playing sound: \(soundName)")
                sound.play()
            } else {
                print("❌ Failed to load sound: \(soundName)")
            }
        } else {
            print("❌ Sound file not found: \(soundName)")
            // Try to list all files in the bundle
            let bundleURL = Bundle.main.bundleURL
            do {
                let files = try FileManager.default.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil)
                print("Files in bundle: \(files)")
            } catch {
                print("Failed to list bundle directory: \(error)")
            }
        }
    }
    
    /// Play start recording sound
    private func playStartRecordingSound() {
        guard isAudioFeedbackEnabled() else { return }
        playSound(named: "start_recording.aiff")
    }
    
    /// Play stop recording sound
    private func playStopRecordingSound() {
        guard isAudioFeedbackEnabled() else { return }
        playSound(named: "stop_recording.aiff")
    }
    
    /// Play process completed sound
    private func playProcessCompletedSound() {
        guard isAudioFeedbackEnabled() else { return }
        // Try different completion sounds - more subtle than start/stop
        if let sound = NSSound(named: "Tink") {
            sound.play()
            print("🔊 Playing completion sound (Tink)")
        } else if let sound = NSSound(named: "Pop") {
            sound.play()
            print("🔊 Playing completion sound (Pop)")
        } else if let sound = NSSound(named: "Ping") {
            sound.play()
            print("🔊 Playing completion sound (Ping)")
        } else {
            // Different beep for completion (check audio feedback setting)
            if isAudioFeedbackEnabled() {
                for _ in 0..<2 {
                    NSSound.beep()
                }
                print("🔊 Playing completion sound (double beep)")
            }
        }
    }
    
    func toggleRecording(mode: VoiceRecordingMode = .transcription) async {
        print("🎤 Toggling voice recording, current state: \(isRecording), mode: \(mode)")
        
        // If currently recording, stop it
        if isRecording {
            print("🎤 Stopping current recording...")
            await stopRecording()
            return
        }
        
        // If not recording but processing, interrupt and start new recording
        if !isRecording {
            print("🎤 Starting new recording with mode: \(mode)")
            // Hide any current HUD first
            HUD.hide()
            await startRecording(mode: mode)
        }
    }
    
    /// Enable or disable system volume control during recording
    func setVolumeControlEnabled(_ enabled: Bool) {
        isVolumeControlEnabled = enabled
    }
    
    /// Toggle recording for speech to text mode
    func toggleSpeechToTextRecording() async {
        print("🎤 toggleSpeechToTextRecording called, current state: \(isRecording)")
        if isRecording {
            print("🎤 Speech to text recording stopped")
            await stopRecording()
        } else {
            print("🎤 Speech to text recording started")
            await startRecording(mode: .transcription)
        }
    }
    
    func startRecording(mode: VoiceRecordingMode = .transcription) async {
        print("🎤 Attempting to start recording with mode: \(mode)")
        
        // Check if already recording (but allow for legitimate toggle calls)
        if isRecording {
            print("🎤 Recording already in progress")
            return
        }
        
        // Check permission first
        guard await checkMicrophonePermission() else {
            print("❌ Microphone permission denied")
            HUD.showError("Microphone permission required")
            return
        }
        
        print("🎤 Microphone permission granted")
        
        // Play start recording sound first
        playStartRecordingSound()
        
        // Save current system volume and mute it during recording
        if isVolumeControlEnabled {
            previousVolume = getCurrentSystemVolume()
            muteSystemVolume()
            print("🔇 System volume muted, saved volume: \(previousVolume)")
        }
        
        // Stop any existing recording
        await stopRecording()
        
        // Set the current mode
        currentMode = mode
        
        // Reset silence detection and animation smoothing
        hasDetectedAudio = false
        previousAudioLevel = 0.0
        
        // Create unique filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let audioURL = documentsPath.appendingPathComponent("voice_recording_\(timestamp).m4a")
        
        // Audio recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            print("🎤 Setting up audio recorder with URL: \(audioURL)")
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            if audioRecorder?.record() == true {
                isRecording = true
                recordingStartTime = Date()
                startTimers()
                
                // Show recording HUD
                Task { @MainActor in
                    HUD.showVoiceRecording(duration: 0, audioLevel: 0)
                }
                
                print("🎤 Started recording to: \(audioURL.lastPathComponent)")
            } else {
                print("❌ Failed to start audio recorder")
            }
        } catch {
            print("❌ Failed to start recording: \(error)")
            
            // Restore volume if recording failed
            if isVolumeControlEnabled {
                setSystemVolume(to: previousVolume)
                print("🔊 System volume restored due to recording failure")
            }
        }
    }
    
    func stopRecording() async {
        guard isRecording else { return }
        
        stopTimers()
        audioRecorder?.stop()
        
        // Restore system volume BEFORE playing stop sound
        if isVolumeControlEnabled {
            setSystemVolume(to: previousVolume)
            print("🔊 System volume restored to: \(previousVolume)")
        }
        
        // Play stop recording sound after volume is restored
        playStopRecordingSound()
        
        // Show processing immediately
        HUD.show("Processing audio...")
        
        if let audioURL = audioRecorder?.url {
            print("🎤 Stopped recording: \(audioURL.lastPathComponent)")
            
            // Process the recorded audio
            await processRecording(audioURL: audioURL)
        }
        
        isRecording = false
        audioLevel = 0.0
        recordingDuration = 0.0
        recordingStartTime = nil
        audioRecorder = nil
    }
    
    private func startTimers() {
        // Timer for recording duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
        
        // Timer for audio level - Balanced update frequency
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in // Smooth but not excessive
            Task { @MainActor in
                guard let self = self, let recorder = self.audioRecorder else { return }
                recorder.updateMeters()
                let averagePower = recorder.averagePower(forChannel: 0)
                let peakPower = recorder.peakPower(forChannel: 0)
                
                // More balanced audio level calculation
                let combinedPower = (averagePower + peakPower) / 2
                
                // Convert decibel to linear with better noise floor
                let normalizedDB = max(-60, combinedPower) // Better noise floor at -60dB
                let linearLevel = pow(10, normalizedDB / 20) // Standard dB to linear conversion
                
                // Moderate sensitivity boost - much more conservative
                var animationLevel = linearLevel
                if animationLevel < 0.01 {
                    animationLevel = 0.0 // True silence = no animation
                } else if animationLevel < 0.05 {
                    animationLevel *= 4.5 // Higher boost for quiet speech visibility
                } else if animationLevel < 0.2 {
                    animationLevel *= 2.5 // Boost for normal speech
                }
                
                // Apply smoothing for better animation flow
                let rawLevel = min(1.0, max(0.0, animationLevel))
                
                // Exponential moving average for smooth transitions
                self.audioLevel = (rawLevel * self.smoothingFactor) + (self.previousAudioLevel * (1.0 - self.smoothingFactor))
                self.previousAudioLevel = self.audioLevel
                
                // Check if we've detected meaningful audio
                if !self.hasDetectedAudio && self.audioLevel > self.silenceThreshold {
                    self.hasDetectedAudio = true
                    print("🎤 Audio detected! Level: \(self.audioLevel)")
                }
                
                // Update HUD with current values
                HUD.updateVoiceRecording(duration: self.recordingDuration, audioLevel: self.audioLevel)
            }
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        recordingTimer = nil
        levelTimer = nil
    }
    
    private func processRecording(audioURL: URL) async {
        // Check if we detected any meaningful audio during recording
        guard hasDetectedAudio else {
            print("🔇 No audio detected during recording, skipping transcription")
            
            // Clean up the audio file
            try? FileManager.default.removeItem(at: audioURL)
            
            // Show message to user
            HUD.showError("No speech detected")
            return
        }
        
        // Also check minimum recording duration if audio was detected
        guard recordingDuration >= minSpeechDuration else {
            print("🔇 Recording too short (\(recordingDuration)s), skipping transcription")
            
            // Clean up the audio file
            try? FileManager.default.removeItem(at: audioURL)
            
            // Show message to user
            HUD.showError("Recording too short")
            return
        }
        
        print("🎤 Processing audio recording with duration: \(recordingDuration)s")
        
        // Here we'll send the audio to OpenAI Whisper API
        do {
            let transcription = try await transcribeAudio(audioURL: audioURL)
            
            // Clean up the audio file
            try? FileManager.default.removeItem(at: audioURL)
            
            // Process based on the current mode
            await handleTranscriptionResult(transcription)
            
        } catch {
            print("❌ Failed to transcribe audio: \(error)")
            HUD.showError("Failed to transcribe audio: \(error.localizedDescription)")
        }
    }
    
    private func handleTranscriptionResult(_ transcription: String) async {
        // If transcription is empty after filtering, don't do anything
        guard !transcription.isEmpty else {
            print("🔇 Empty transcription after filtering - no action taken")
            HUD.showError("No speech detected")
            return
        }
        
        switch currentMode {
        case .transcription:
            // Simple transcription - copy to clipboard and paste if possible
            let copied = ClipboardHelper.writeAndVerify(transcription)
            
            // Try to paste into the active application
            let pasted = ClipboardHelper.pasteIntoApplication()
            
            // Play completion sound when process is done
            playProcessCompletedSound()
            
            if pasted {
                HUD.showSuccess("Transcription pasted into application")
            } else if copied {
                HUD.showSuccess("Transcription copied to clipboard")
            } else {
                HUD.showResult(transcription, title: "Voice Transcription")
            }
            
        case .enhancement:
            // Use transcription as input for prompt enhancement
            await processEnhancement(transcription)
            // Play completion sound after enhancement
            playProcessCompletedSound()
            
        case .translation:
            // Use transcription as input for translation
            await processTranslation(transcription)
            // Play completion sound after translation
            playProcessCompletedSound()
        }
    }
    
    private func processEnhancement(_ text: String) async {
        // Get AppState instance to run enhancement
        NotificationCenter.default.post(
            name: NSNotification.Name("ProcessVoiceEnhancement"),
            object: nil,
            userInfo: ["text": text]
        )
    }
    
    private func processTranslation(_ text: String) async {
        // Get AppState instance to run translation
        NotificationCenter.default.post(
            name: NSNotification.Name("ProcessVoiceTranslation"),
            object: nil,
            userInfo: ["text": text]
        )
    }
    
    private func transcribeAudio(audioURL: URL) async throws -> String {
        // Get API key from keychain
        guard let apiKey = KeychainHelper.loadAPIKey(), !apiKey.isEmpty else {
            throw NSError(domain: "VoiceRecording", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not found. Please set it in settings."])
        }
        
        // Create OpenAI client and transcribe
        let client = OpenAIClient(apiKey: apiKey)
        let rawTranscription = try await client.transcribeAudio(audioURL: audioURL)
        
        // Filter out meaningless results
        return filterTranscriptionResult(rawTranscription)
    }
    
    /// Filter out meaningless or hallucinated transcription results
    private func filterTranscriptionResult(_ text: String) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Check if the text is too short or meaningless
        if cleanText.count < 3 {
            return ""
        }
        
        // Check if it's mostly punctuation or single characters
        let alphaNumericCount = cleanText.filter { $0.isLetter || $0.isNumber }.count
        if alphaNumericCount < 3 {
            print("🚫 Filtered out non-meaningful text: '\(text)'")
            return ""
        }
        
        print("✅ Transcription passed filter: '\(text)'")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func showTranscriptionResult(_ text: String) async {
        // Show the result in HUD
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowTranscriptionResult"),
            object: nil,
            userInfo: ["transcription": text]
        )
    }
}

// MARK: - AVAudioRecorderDelegate
extension VoiceRecordingManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("❌ Recording finished unsuccessfully")
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("❌ Recording error: \(error)")
        }
    }
}
