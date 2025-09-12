import CoreGraphics
import SwiftUI
import AppKit
import ApplicationServices
import ServiceManagement
import AVFoundation

/// Main application state coordinator
@MainActor
final class AppState: ObservableObject {
    // Configuration modules
    @ObservedObject var configuration = AppConfiguration()
    @ObservedObject var hotkeyConfig = HotkeyConfiguration()
    @ObservedObject var translationConfig = TranslationConfiguration()
    
    // Speech-to-text configuration
    @Published var speechToTextToggleEnabled = UserDefaults.standard.bool(forKey: "speechToTextToggleEnabled") {
        didSet { 
            UserDefaults.standard.set(speechToTextToggleEnabled, forKey: "speechToTextToggleEnabled")
            if speechToTextToggleEnabled {
                setupSpeechToTextToggle()
            } else {
                if let monitor = speechToTextToggleMonitor {
                    NSEvent.removeMonitor(monitor)
                    speechToTextToggleMonitor = nil
                }
            }
        }
    }
    @Published var speechToTextToggleKey = UserDefaults.standard.string(forKey: "speechToTextToggleKey") ?? "left_cmd" {
        didSet {
            UserDefaults.standard.set(speechToTextToggleKey, forKey: "speechToTextToggleKey")
            if speechToTextToggleEnabled {
                if let monitor = speechToTextToggleMonitor {
                    NSEvent.removeMonitor(monitor)
                    speechToTextToggleMonitor = nil
                }
                setupSpeechToTextToggle()
            }
        }
    }
    
    @Published var frontmostBundleID: String?
    @Published var lastActiveApp: NSRunningApplication?
    @Published var voiceRecordingManager = VoiceRecordingManager()
    
    private var wsObserver: Any?
    private var speechToTextToggleMonitor: Any?
    private var lastModifierFlags: NSEvent.ModifierFlags = []

    init() {
        // Perform startup diagnostics and cleanup
        performStartupDiagnostics()
        
        setupWorkspaceObserver()
        hotkeyConfig.configure(with: self)
        setupVoiceRecordingNotifications()
        
        if speechToTextToggleEnabled {
            setupSpeechToTextToggle()
        }
    }

    deinit {
        if let o = wsObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
        }
        
        if let monitor = speechToTextToggleMonitor {
            NSEvent.removeMonitor(monitor)
            speechToTextToggleMonitor = nil
        }
    }
    
    private func setupWorkspaceObserver() {
        wsObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                self.lastActiveApp = app
            }
        }
    }
    
    func guessTopWindowApp() -> NSRunningApplication? {
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return nil }
        for w in info {
            guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let pid = w[kCGWindowOwnerPID as String] as? pid_t else { continue }
            if let app = NSRunningApplication(processIdentifier: pid),
               app.bundleIdentifier != Bundle.main.bundleIdentifier { return app }
        }
        return nil
    }

    // MARK: - Main Actions

    func runTranslation() async {
        let permissions = Permission.checkAllPermissions()
        
        if !permissions.hasAccessibility {
            HUD.showError("Accessibility permission required.\nGrant access in System Settings.")
            Permission.openPrivacyPane(for: .accessibility)
            playErrorBeep()
            return
        }
        
        if !permissions.hasInputMonitoring {
            print("⚠️ Input monitoring permission missing but continuing...")
        }
        
        let initialFrontmost = NSWorkspace.shared.frontmostApplication
        let target = lastActiveApp ?? initialFrontmost ?? guessTopWindowApp()
        target?.activate(options: [])
        usleep(250_000)

        HUD.show("Reading text for translation…")
        let original: String
        let isFromSelection: Bool
        
        let selectionResult = ClipboardHelper.readSelectionStrict(allowClipboardFallback: configuration.useClipboardFallback)
        if let selectedText = selectionResult.text, !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            original = selectedText
            isFromSelection = selectionResult.diag.contains("AX:") || selectionResult.diag.contains("Cmd+C:")
        } else {
            if configuration.useClipboardFallback {
                HUD.update("No selection found, trying clipboard…")
                let read = ClipboardHelper.readClipboardOnly()
                guard let text = read.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    HUD.showError("No text found.\nSelect text or copy to clipboard.")
                    playErrorBeep()
                    return
                }
                original = text
                isFromSelection = false
            } else {
                HUD.showError("No text selected.\nSelect text to translate.")
                playErrorBeep()
                return
            }
        }

        var key = configuration.apiKey
        if key.isEmpty, let saved = KeychainHelper.promptAndSave() {
            key = saved
            configuration.apiKey = saved
        }
        guard !key.isEmpty else {
            playErrorBeep()
            HUD.showError("OpenAI API key required.\nAdd key in Settings.")
            return
        }

        HUD.update("Translating \(translationConfig.sourceLanguage) → \(translationConfig.targetLanguage)…")
        let system = translationConfig.buildTranslationPrompt()
        
        do {
            let translated = try await OpenAIClient(apiKey: key).polish(system: system, user: original, model: configuration.selectedModel)
            
            if isFromSelection {
                let replaced = ClipboardHelper.replaceSelectedText(translated)
                if replaced {
                    HUD.showSuccess("Text translated successfully")
                } else {
                    let copied = ClipboardHelper.writeAndVerify(translated)
                    if copied {
                        HUD.showSuccess("Translation copied to clipboard")
                    } else {
                        HUD.showResult(translated, title: "Translation Result")
                    }
                }
            } else {
                let copied = ClipboardHelper.writeAndVerify(translated)
                if copied {
                    HUD.showSuccess("Translation copied to clipboard")
                } else {
                    HUD.showResult(translated, title: "Translation Result")
                }
            }
        } catch {
            HUD.showError("Translation error:\n\((error as NSError).localizedDescription)")
            playErrorBeep()
        }
    }

    func runOnce() async {
        let permissions = Permission.checkAllPermissions()
        
        if !permissions.hasAccessibility {
            HUD.showError("Accessibility permission required.\nGrant access in System Settings.")
            Permission.openPrivacyPane(for: .accessibility)
            playErrorBeep()
            return
        }
        
        if !permissions.hasInputMonitoring {
            print("⚠️ Input monitoring permission missing but continuing...")
        }
        
        let initialFrontmost = NSWorkspace.shared.frontmostApplication
        let target = lastActiveApp ?? initialFrontmost ?? guessTopWindowApp()
        target?.activate(options: [])
        usleep(250_000)

        HUD.show("Reading selection…")
        let original: String
        let isFromSelection: Bool
        
        let selectionResult = ClipboardHelper.readSelectionStrict(allowClipboardFallback: configuration.useClipboardFallback)
        if let selectedText = selectionResult.text, !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            original = selectedText
            isFromSelection = selectionResult.diag.contains("AX:") || selectionResult.diag.contains("Cmd+C:")
        } else {
            if configuration.useClipboardFallback {
                HUD.update("No selection found, trying clipboard…")
                let read = ClipboardHelper.readClipboardOnly()
                guard let text = read.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    HUD.showError("No text found.\nSelect text or copy to clipboard.")
                    playErrorBeep()
                    return
                }
                original = text
                isFromSelection = false
            } else {
                HUD.showError("No text selected.\nSelect text to enhance.")
                playErrorBeep()
                return
            }
        }

        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        self.frontmostBundleID = bundleID

        var key = configuration.apiKey
        if key.isEmpty, let saved = KeychainHelper.promptAndSave() {
            key = saved
            configuration.apiKey = saved
        }
        guard !key.isEmpty else {
            playErrorBeep()
            HUD.showError("OpenAI API key required.\nAdd key in Settings.")
            return
        }

        HUD.update("Enhancing your text…")
        
        let detectedLanguage = translationConfig.detectLanguage(original)
        let system = PromptService.buildSystemPrompt(
            bundleID: bundleID, 
            autoTranslate: configuration.autoTranslate, 
            inputText: original,
            detectedLanguage: detectedLanguage
        )
        
        do {
            let improved = try await OpenAIClient(apiKey: key).polish(system: system, user: original, model: configuration.selectedModel)
            
            let finalText: String
            if PromptService.isAIClarificationRequest(improved) {
                finalText = "! " + improved
            } else {
                finalText = improved
            }
            
            if isFromSelection {
                let replaced = ClipboardHelper.replaceSelectedText(finalText)
                
                if replaced {
                    HUD.showSuccess("Text replaced successfully")
                } else {
                    let copied = ClipboardHelper.writeAndVerify(finalText)
                    if copied {
                        HUD.showSuccess("Text copied to clipboard")
                    } else {
                        HUD.showResult(finalText, title: "Promptify — Result")
                    }
                }
            } else {
                let copied = ClipboardHelper.writeAndVerify(finalText)
                
                if copied {
                    HUD.showSuccess("Text copied to clipboard")
                } else {
                    HUD.showResult(finalText, title: "Promptify — Result")
                }
            }
        } catch {
            HUD.showError("OpenAI error:\n\((error as NSError).localizedDescription)")
            playErrorBeep()
        }
    }

    // MARK: - Voice Input Handlers
    
    private func setupVoiceRecordingNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ProcessVoiceEnhancement"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let text = notification.userInfo?["text"] as? String else { return }
            Task { await self.runEnhancementWithVoiceInput(text) }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ProcessVoiceTranslation"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let text = notification.userInfo?["text"] as? String else { return }
            Task { await self.runTranslationWithVoiceInput(text) }
        }
    }
    
    private func runEnhancementWithVoiceInput(_ voiceText: String) async {
        let permissions = Permission.checkAllPermissions()
        
        if !permissions.hasAccessibility {
            HUD.showError("Accessibility permission required.\nGrant access in System Settings.")
            Permission.openPrivacyPane(for: .accessibility)
            playErrorBeep()
            return
        }
        
        HUD.show("Enhancing voice input…")
        
        var key = configuration.apiKey
        if key.isEmpty, let saved = KeychainHelper.promptAndSave() {
            key = saved
            configuration.apiKey = saved
        }
        guard !key.isEmpty else {
            playErrorBeep()
            HUD.showError("OpenAI API key required.\nAdd key in Settings.")
            return
        }

        let detectedLanguage = translationConfig.detectLanguage(voiceText)
        let system = PromptService.buildSystemPrompt(
            bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier, 
            autoTranslate: configuration.autoTranslate, 
            inputText: voiceText,
            detectedLanguage: detectedLanguage
        )
        
        do {
            let improved = try await OpenAIClient(apiKey: key).polish(system: system, user: voiceText, model: configuration.selectedModel)
            
            let finalText: String
            if PromptService.isAIClarificationRequest(improved) {
                finalText = "! " + improved
            } else {
                finalText = improved
            }
            
            let copied = ClipboardHelper.writeAndVerify(finalText)
            
            let targetApp = lastActiveApp ?? NSWorkspace.shared.frontmostApplication
            if targetApp != nil {
                let pasted = ClipboardHelper.pasteIntoApplication()
                if pasted {
                    HUD.showSuccess("Enhanced text pasted into application")
                } else if copied {
                    HUD.showSuccess("Enhanced text copied to clipboard")
                } else {
                    HUD.showResult(finalText, title: "Promptify — Enhanced Voice Input")
                }
            } else if copied {
                HUD.showSuccess("Enhanced text copied to clipboard")
            } else {
                HUD.showResult(finalText, title: "Promptify — Enhanced Voice Input")
            }
        } catch {
            HUD.showError("OpenAI error:\n\((error as NSError).localizedDescription)")
            playErrorBeep()
        }
    }
    
    private func runTranslationWithVoiceInput(_ voiceText: String) async {
        let permissions = Permission.checkAllPermissions()
        
        if !permissions.hasAccessibility {
            HUD.showError("Accessibility permission required.\nGrant access in System Settings.")
            Permission.openPrivacyPane(for: .accessibility)
            playErrorBeep()
            return
        }

        HUD.show("Translating voice input…")
        
        var key = configuration.apiKey
        if key.isEmpty, let saved = KeychainHelper.promptAndSave() {
            key = saved
            configuration.apiKey = saved
        }
        guard !key.isEmpty else {
            playErrorBeep()
            HUD.showError("OpenAI API key required.\nAdd key in Settings.")
            return
        }

        HUD.update("Translating \(translationConfig.sourceLanguage) → \(translationConfig.targetLanguage)…")
        let system = translationConfig.buildTranslationPrompt()
        
        do {
            let translated = try await OpenAIClient(apiKey: key).polish(system: system, user: voiceText, model: configuration.selectedModel)
            
            let copied = ClipboardHelper.writeAndVerify(translated)
            
            let targetApp = lastActiveApp ?? NSWorkspace.shared.frontmostApplication
            if targetApp != nil {
                let pasted = ClipboardHelper.pasteIntoApplication()
                if pasted {
                    HUD.showSuccess("Translated text pasted into application")
                } else if copied {
                    HUD.showSuccess("Translation copied to clipboard")
                } else {
                    HUD.showResult(translated, title: "Translation Result")
                }
            } else if copied {
                HUD.showSuccess("Translation copied to clipboard")
            } else {
                HUD.showResult(translated, title: "Translation Result")
            }
        } catch {
            HUD.showError("Translation error:\n\((error as NSError).localizedDescription)")
            playErrorBeep()
        }
    }
    
    // MARK: - Speech to Text Toggle Setup
    func setupSpeechToTextToggle() {
        print("Setting up speech to text toggle monitoring...")
        
        if let monitor = speechToTextToggleMonitor {
            print("Removing existing speech to text toggle monitor")
            NSEvent.removeMonitor(monitor)
            speechToTextToggleMonitor = nil
        }
        
        guard speechToTextToggleEnabled else {
            print("Speech to text toggle is disabled, not setting up monitoring")
            return
        }
        
        let keyCode = getKeyCodeForToggleKey(speechToTextToggleKey)
        print("Speech to text toggle key code: \(keyCode) for key: \(speechToTextToggleKey)")
        
        speechToTextToggleMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged],
            handler: { [weak self] event in
                self?.handleSpeechToTextToggleEvent(event, keyCode: keyCode)
            }
        )
        
        print("Speech to text toggle monitoring started with key: \(speechToTextToggleKey), keyCode: \(keyCode)")
    }
    
    private func getKeyCodeForToggleKey(_ key: String) -> UInt16 {
        print("Getting key code for toggle key: \(key)")
        let keyCode: UInt16
        switch key {
        case "left_cmd": keyCode = 55
        case "right_cmd": keyCode = 54
        case "left_opt": keyCode = 58
        case "right_opt": keyCode = 61
        case "left_ctrl": keyCode = 59
        case "right_ctrl": keyCode = 62
        case "left_shift": keyCode = 56
        case "right_shift": keyCode = 60
        case "fn": keyCode = 63
        case "space": keyCode = 49
        default: keyCode = 55
        }
        print("Key code for \(key): \(keyCode)")
        return keyCode
    }
    
    private func handleSpeechToTextToggleEvent(_ event: NSEvent, keyCode: UInt16) {
        print("Speech to text toggle event received: type=\(event.type), keyCode=\(event.keyCode), expectedKeyCode=\(keyCode), modifierFlags=\(event.modifierFlags)")
        
        guard speechToTextToggleEnabled else { 
            print("Speech to text toggle is disabled")
            return 
        }
        
        var shouldToggle = false
        
        if event.keyCode == keyCode {
            if isModifierKey(keyCode) && event.type == .flagsChanged {
                let currentPressed = event.modifierFlags.contains(getModifierFlagForKeyCode(keyCode))
                let wasPressed = lastModifierFlags.contains(getModifierFlagForKeyCode(keyCode))
                
                print("Modifier key \(keyCode) flagsChanged: currentPressed=\(currentPressed), wasPressed=\(wasPressed)")
                
                if currentPressed && !wasPressed {
                    print("Specific modifier key pressed (state changed), should toggle")
                    shouldToggle = true
                }
                
                lastModifierFlags = event.modifierFlags
            } else if !isModifierKey(keyCode) && event.type == .keyDown {
                print("Regular key \(keyCode) pressed")
                shouldToggle = true
            }
        }
        
        if shouldToggle {
            print("Toggling speech to text recording...")
            Task { @MainActor in
                await self.voiceRecordingManager.toggleSpeechToTextRecording()
            }
        }
    }
    
    private func isModifierKey(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case 54, 55: return true // Right/Left Command
        case 58, 61: return true // Left/Right Option
        case 59, 62: return true // Left/Right Control
        case 56, 60: return true // Left/Right Shift
        case 63: return true // Fn key
        default: return false
        }
    }
    
    private func getModifierFlagForKeyCode(_ keyCode: UInt16) -> NSEvent.ModifierFlags {
        switch keyCode {
        case 54, 55: return .command
        case 58, 61: return .option
        case 59, 62: return .control
        case 56, 60: return .shift
        case 63: return .function
        default: return []
        }
    }
    
    // MARK: - Startup & Diagnostic Methods
    
    private func performStartupDiagnostics() {
        print("🔍 Performing startup diagnostics...")
        
        // Run permission diagnostic
        let _ = PermissionDiagnostic.performDiagnostic()
        
        // Perform settings migration if needed
        SettingsMigrator.migrateIfNeeded()
        
        // Restore settings from backup if available
        SettingsMigrator.restoreFromBackupIfNeeded()
        
        // Clean up deprecated settings
        SettingsMigrator.cleanupDeprecatedSettings()
        
        // Validate and fix current settings
        SettingsMigrator.validateAndFixSettings()
        
        print("✅ Startup diagnostics completed")
    }
    
    // MARK: - Utility Methods
    
    private func playErrorBeep() {
        if configuration.enableAudioFeedback {
            NSSound.beep()
        }
    }
}