//
//  AppState.swift
//  Promptify
//
//  Created by Mehmet Sağır on 7.09.2025.
//

import CoreGraphics
import SwiftUI
import AppKit
import HotKey
import ApplicationServices
import ServiceManagement
import AVFoundation

@MainActor
final class AppState: ObservableObject {
    // UI state
    @Published var apiKey: String = KeychainHelper.loadAPIKey() ?? ""
    @Published var autoTranslate = UserDefaults.standard.bool(forKey: "autoTranslate") {
        didSet { UserDefaults.standard.set(autoTranslate, forKey: "autoTranslate") }
    }
    @Published var launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin") {
        didSet { 
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            setLaunchAtLogin(launchAtLogin)
        }
    }
    @Published var selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "gpt-3.5-turbo" {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }
    @Published var customHotkeyKey = UserDefaults.standard.string(forKey: "customHotkeyKey") ?? "k" {
        didSet { 
            UserDefaults.standard.set(customHotkeyKey, forKey: "customHotkeyKey")
            setupHotkey() // Hotkey'i yeniden ayarla
        }
    }
    @Published var customHotkeyModifiers = UserDefaults.standard.integer(forKey: "customHotkeyModifiers") {
        didSet { 
            UserDefaults.standard.set(customHotkeyModifiers, forKey: "customHotkeyModifiers")
            setupHotkey() // Hotkey'i yeniden ayarla
        }
    }
    @Published var useClipboardFallback = UserDefaults.standard.bool(forKey: "useClipboardFallback") {
        didSet { UserDefaults.standard.set(useClipboardFallback, forKey: "useClipboardFallback") }
    }
    @Published var enableAudioFeedback = UserDefaults.standard.object(forKey: "enableAudioFeedback") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enableAudioFeedback, forKey: "enableAudioFeedback") }
    }
    @Published var hideFromDock = UserDefaults.standard.bool(forKey: "hideFromDock") {
        didSet { 
            UserDefaults.standard.set(hideFromDock, forKey: "hideFromDock")
            updateDockVisibility()
        }
    }
    @Published var translationEnabled = UserDefaults.standard.bool(forKey: "translationEnabled") {
        didSet { 
            UserDefaults.standard.set(translationEnabled, forKey: "translationEnabled")
            setupTranslationHotkey() // Translation açılıp kapatıldığında hotkey'i güncelle
        }
    }
    @Published var sourceLanguage = UserDefaults.standard.string(forKey: "sourceLanguage") ?? "Turkish" {
        didSet { UserDefaults.standard.set(sourceLanguage, forKey: "sourceLanguage") }
    }
    @Published var targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "English" {
        didSet { UserDefaults.standard.set(targetLanguage, forKey: "targetLanguage") }
    }
    @Published var translationHotkeyKey = UserDefaults.standard.string(forKey: "translationHotkeyKey") ?? "t" {
        didSet { 
            UserDefaults.standard.set(translationHotkeyKey, forKey: "translationHotkeyKey")
            setupTranslationHotkey()
        }
    }
    @Published var translationHotkeyModifiers = UserDefaults.standard.integer(forKey: "translationHotkeyModifiers") {
        didSet { 
            UserDefaults.standard.set(translationHotkeyModifiers, forKey: "translationHotkeyModifiers")
            setupTranslationHotkey()
        }
    }
    // Voice recording mode is handled by speech to text toggle, no separate hotkeys needed
    @Published var speechToTextToggleEnabled = UserDefaults.standard.bool(forKey: "speechToTextToggleEnabled") {
        didSet { 
            UserDefaults.standard.set(speechToTextToggleEnabled, forKey: "speechToTextToggleEnabled")
            if speechToTextToggleEnabled {
                setupSpeechToTextToggle()
            } else {
                // Remove speech to text toggle monitor
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
                // Remove existing monitor and set up new one
                if let monitor = speechToTextToggleMonitor {
                    NSEvent.removeMonitor(monitor)
                    speechToTextToggleMonitor = nil
                }
                setupSpeechToTextToggle()
            }
        }
    }
    
    // Separate hotkeys for voice enhancement and translation modes
    @Published var voiceEnhancementHotkeyKey = UserDefaults.standard.string(forKey: "voiceEnhancementHotkeyKey") ?? "" {
        didSet { 
            UserDefaults.standard.set(voiceEnhancementHotkeyKey, forKey: "voiceEnhancementHotkeyKey")
            setupVoiceEnhancementHotkey()
        }
    }
    @Published var voiceEnhancementHotkeyModifiers = UserDefaults.standard.integer(forKey: "voiceEnhancementHotkeyModifiers") {
        didSet { 
            UserDefaults.standard.set(voiceEnhancementHotkeyModifiers, forKey: "voiceEnhancementHotkeyModifiers")
            setupVoiceEnhancementHotkey()
        }
    }
    @Published var voiceTranslationHotkeyKey = UserDefaults.standard.string(forKey: "voiceTranslationHotkeyKey") ?? "" {
        didSet { 
            UserDefaults.standard.set(voiceTranslationHotkeyKey, forKey: "voiceTranslationHotkeyKey")
            setupVoiceTranslationHotkey()
        }
    }
    @Published var voiceTranslationHotkeyModifiers = UserDefaults.standard.integer(forKey: "voiceTranslationHotkeyModifiers") {
        didSet { 
            UserDefaults.standard.set(voiceTranslationHotkeyModifiers, forKey: "voiceTranslationHotkeyModifiers")
            setupVoiceTranslationHotkey()
        }
    }
    @Published var frontmostBundleID: String?

    // Global shortcuts
    private var hotKey: HotKey?
    private var translationHotKey: HotKey?
    private var voiceEnhancementHotKey: HotKey?
    private var voiceTranslationHotKey: HotKey?

    // Menüden çalıştırıldığında odakı geri verebilmek için
    @Published var lastActiveApp: NSRunningApplication?
    private var wsObserver: Any?
    
    // Voice recording manager
    @Published var voiceRecordingManager = VoiceRecordingManager()
    
    // Push-to-talk monitoring (deprecated)
    private var pushToTalkMonitor: Any?
    private var isPushToTalkActive = false
    
    // Speech to text toggle monitoring
    private var speechToTextToggleMonitor: Any?
    private var lastModifierFlags: NSEvent.ModifierFlags = []

    // Son aktif uygulamayı takip et
    init() {
        // İlk kez çalıştırılıyorsa varsayılan değerleri ayarla
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "autoTranslate")
            UserDefaults.standard.set(true, forKey: "launchAtLogin")
            UserDefaults.standard.set("gpt-3.5-turbo", forKey: "selectedModel")
            UserDefaults.standard.set("k", forKey: "customHotkeyKey")
            UserDefaults.standard.set(Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue), forKey: "customHotkeyModifiers")
            UserDefaults.standard.set(true, forKey: "useClipboardFallback")
            UserDefaults.standard.set(true, forKey: "enableAudioFeedback")
            UserDefaults.standard.set(false, forKey: "hideFromDock")
            UserDefaults.standard.set(false, forKey: "translationEnabled")
            UserDefaults.standard.set("Turkish", forKey: "sourceLanguage")
            UserDefaults.standard.set("English", forKey: "targetLanguage")
            UserDefaults.standard.set("t", forKey: "translationHotkeyKey")
            UserDefaults.standard.set(Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue), forKey: "translationHotkeyModifiers")
            UserDefaults.standard.set("e", forKey: "voiceEnhancementHotkeyKey")
            UserDefaults.standard.set(Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue), forKey: "voiceEnhancementHotkeyModifiers")
            UserDefaults.standard.set("r", forKey: "voiceTranslationHotkeyKey")
            UserDefaults.standard.set(Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue), forKey: "voiceTranslationHotkeyModifiers")
            UserDefaults.standard.set(false, forKey: "speechToTextToggleEnabled")
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            
            // Published property'leri güncelle
            autoTranslate = true
            launchAtLogin = true
            hideFromDock = false
            selectedModel = "gpt-3.5-turbo"
            customHotkeyKey = "k"
            customHotkeyModifiers = Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue)
            useClipboardFallback = true
            enableAudioFeedback = true
            translationEnabled = false
            sourceLanguage = "Turkish"
            targetLanguage = "English"
            translationHotkeyKey = "t"
            translationHotkeyModifiers = Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue)
            voiceEnhancementHotkeyKey = "e"
            voiceEnhancementHotkeyModifiers = Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
            voiceTranslationHotkeyKey = "r"
            voiceTranslationHotkeyModifiers = Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
            speechToTextToggleEnabled = false
        }
        
        // Uygulama ilk başlatıldığında ayarlar penceresini aç
        if isFirstLaunch {
            DispatchQueue.main.async {
                // AppDelegate'ta işlenecek
            }
        }
        
        wsObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            // Promptify değilse hatırla
            if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                self.lastActiveApp = app
            }
        }
        
        // Hotkey'leri başlangıçta kur
        setupHotkey()
        setupTranslationHotkey()
        setupVoiceRecordingHotkey()
        setupVoiceEnhancementHotkey()
        setupVoiceTranslationHotkey()
        
        // Voice recording result handlers
        setupVoiceRecordingNotifications()
        
        // Setup speech to text toggle monitoring if enabled
        if speechToTextToggleEnabled {
            setupSpeechToTextToggle()
        }
    }

    deinit {
        if let o = wsObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
        }
        
        // Remove speech to text toggle monitor
        if let monitor = speechToTextToggleMonitor {
            NSEvent.removeMonitor(monitor)
            speechToTextToggleMonitor = nil
        }
        
        // Remove deprecated push to talk monitor if it exists
        if let monitor = pushToTalkMonitor {
            NSEvent.removeMonitor(monitor)
            pushToTalkMonitor = nil
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

    // Custom global kısayol
    func setupHotkey() {
        hotKey = nil // Eski hotkey'i temizle
        
        // Key string'ini HotKey.Key'e çevir
        guard let keyCode = keyStringToKeyCode(customHotkeyKey) else { return }
        
        // Modifier integer'ını HotKey.ModifierFlags'a çevir
        let modifierFlags = intToModifierFlags(customHotkeyModifiers)
        
        hotKey = HotKey(key: keyCode, modifiers: modifierFlags)
        hotKey?.keyDownHandler = { [weak self] in
            guard let self else { return }
            Task { await self.runOnce() }
        }
    }
    
    func setupTranslationHotkey() {
        translationHotKey = nil // Eski translation hotkey'i temizle
        
        guard translationEnabled else { return } // Açık değilse hotkey kurma
        
        // Key string'ini HotKey.Key'e çevir
        guard let keyCode = keyStringToKeyCode(translationHotkeyKey) else { return }
        
        // Modifier integer'ını HotKey.ModifierFlags'a çevir
        let modifierFlags = intToModifierFlags(translationHotkeyModifiers)
        
        translationHotKey = HotKey(key: keyCode, modifiers: modifierFlags)
        translationHotKey?.keyDownHandler = { [weak self] in
            guard let self else { return }
            Task { await self.runTranslation() }
        }
    }
    
    // Voice recording mode is handled by speech to text toggle, no separate hotkey setup needed
    func setupVoiceRecordingHotkey() {
        // Clear existing hotkey
        // No hotkey setup needed as speech to text toggle handles this
    }
    
        @MainActor
    private func toggleVoiceRecording() async {
        print("🎤 Toggling voice recording...")
        // Voice recording is now handled by speech to text toggle or separate enhancement/translation hotkeys
        // This function is kept for backward compatibility but doesn't do anything
        print("🎤 Voice recording toggle is now handled by speech to text toggle or enhancement/translation hotkeys")
    }
    
    func setupVoiceEnhancementHotkey() {
        // Clear existing hotkey
        if let existingHotKey = voiceEnhancementHotKey {
            print("🎤 Removing existing voice enhancement hotkey")
        }
        voiceEnhancementHotKey = nil
        
        guard !voiceEnhancementHotkeyKey.isEmpty else { 
            print("🎤 Voice enhancement hotkey not set")
            return 
        }
        
        guard let keyCode = keyStringToKeyCode(voiceEnhancementHotkeyKey) else { 
            print("❌ Invalid voice enhancement hotkey: \(voiceEnhancementHotkeyKey)")
            return 
        }
        
        var modifierFlags = intToModifierFlags(voiceEnhancementHotkeyModifiers)
        
        if modifierFlags.isEmpty {
            modifierFlags = [.command, .shift]
            voiceEnhancementHotkeyModifiers = Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
            print("⚠️ No modifiers set for voice enhancement hotkey, defaulting to Command+Shift")
        }
        
        print("🎤 Setting up voice enhancement hotkey: \(voiceEnhancementHotkeyKey) with modifiers: \(modifierFlags)")
        
        do {
            voiceEnhancementHotKey = HotKey(key: keyCode, modifiers: modifierFlags)
            voiceEnhancementHotKey?.keyDownHandler = { [weak self] in
                guard let self else { return }
                print("🎤 Voice enhancement hotkey pressed!")
                Task { await self.voiceRecordingManager.toggleRecording(mode: .enhancement) }
            }
            print("🎤 Voice enhancement hotkey successfully registered")
        } catch {
            print("❌ Failed to register voice enhancement hotkey: \(error)")
        }
    }
    
    func setupVoiceTranslationHotkey() {
        // Clear existing hotkey
        if let existingHotKey = voiceTranslationHotKey {
            print("🎤 Removing existing voice translation hotkey")
        }
        voiceTranslationHotKey = nil
        
        guard !voiceTranslationHotkeyKey.isEmpty else { 
            print("🎤 Voice translation hotkey not set")
            return 
        }
        
        guard let keyCode = keyStringToKeyCode(voiceTranslationHotkeyKey) else { 
            print("❌ Invalid voice translation hotkey: \(voiceTranslationHotkeyKey)")
            return 
        }
        
        var modifierFlags = intToModifierFlags(voiceTranslationHotkeyModifiers)
        
        if modifierFlags.isEmpty {
            modifierFlags = [.command, .shift]
            voiceTranslationHotkeyModifiers = Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
            print("⚠️ No modifiers set for voice translation hotkey, defaulting to Command+Shift")
        }
        
        print("🎤 Setting up voice translation hotkey: \(voiceTranslationHotkeyKey) with modifiers: \(modifierFlags)")
        
        do {
            voiceTranslationHotKey = HotKey(key: keyCode, modifiers: modifierFlags)
            voiceTranslationHotKey?.keyDownHandler = { [weak self] in
                guard let self else { return }
                print("🎤 Voice translation hotkey pressed!")
                Task { await self.voiceRecordingManager.toggleRecording(mode: .translation) }
            }
            print("🎤 Voice translation hotkey successfully registered")
        } catch {
            print("❌ Failed to register voice translation hotkey: \(error)")
        }
    }
    
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
    
    // Voice input enhancement - similar to runOnce but with voice text instead of selection
    private func runEnhancementWithVoiceInput(_ voiceText: String) async {
        let permissions = Permission.checkAllPermissions()
        
        if !permissions.hasAccessibility {
            HUD.showError("Accessibility permission required.\nGrant access in System Settings.")
            Permission.openPrivacyPane(for: .accessibility); playErrorBeep(); return
        }
        
        HUD.show("Enhancing voice input…")
        
        // API key
        var key = apiKey
        if key.isEmpty, let saved = KeychainHelper.promptAndSave() {
            key = saved
            self.apiKey = saved
        }
        guard !key.isEmpty else {
            playErrorBeep()
            HUD.showError("OpenAI API key required.\nAdd key in Settings.")
            return
        }

        // OpenAI çağrısı (prompt enhancement)
        let system = buildSystemPrompt(bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier, autoTranslate: autoTranslate, inputText: voiceText)
        
        do {
            let improved = try await OpenAIClient(apiKey: key).polish(system: system, user: voiceText, model: selectedModel)
            
            // Enhancement mode'da clarification kontrolü
            let finalText: String
            if isAIClarificationRequest(improved) {
                finalText = "! " + improved
            } else {
                finalText = improved
            }
            
            // Voice input always goes to clipboard
            let copied = ClipboardHelper.writeAndVerify(finalText)
            
            // Check if there's a focused application to paste into
            let targetApp = lastActiveApp ?? NSWorkspace.shared.frontmostApplication
            if targetApp != nil {
                // Try to paste into the target application
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
            HUD.showError("OpenAI error:\n\((error as NSError).localizedDescription)"); playErrorBeep()
        }
    }
    
    // Voice input translation - similar to runTranslation but with voice text
    private func runTranslationWithVoiceInput(_ voiceText: String) async {
        let permissions = Permission.checkAllPermissions()
        
        if !permissions.hasAccessibility {
            HUD.showError("Accessibility permission required.\nGrant access in System Settings.")
            Permission.openPrivacyPane(for: .accessibility); playErrorBeep(); return
        }

        HUD.show("Translating voice input…")
        
        // API key kontrolü
        var key = apiKey
        if key.isEmpty, let saved = KeychainHelper.promptAndSave() {
            key = saved
            self.apiKey = saved
        }
        guard !key.isEmpty else {
            playErrorBeep()
            HUD.showError("OpenAI API key required.\nAdd key in Settings.")
            return
        }

        // Translation çağrısı
        HUD.update("Translating \(sourceLanguage) → \(targetLanguage)…")
        let system = buildTranslationPrompt()
        
        do {
            let translated = try await OpenAIClient(apiKey: key).polish(system: system, user: voiceText, model: selectedModel)
            
            // Voice input always goes to clipboard
            let copied = ClipboardHelper.writeAndVerify(translated)
            
            // Check if there's a focused application to paste into
            let targetApp = lastActiveApp ?? NSWorkspace.shared.frontmostApplication
            if targetApp != nil {
                // Try to paste into the target application
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
            HUD.showError("Translation error:\n\((error as NSError).localizedDescription)"); playErrorBeep()
        }
    }
    
    private func keyStringToKeyCode(_ keyString: String) -> Key? {
        switch keyString.lowercased() {
        case "a": return .a
        case "b": return .b
        case "c": return .c
        case "d": return .d
        case "e": return .e
        case "f": return .f
        case "g": return .g
        case "h": return .h
        case "i": return .i
        case "j": return .j
        case "k": return .k
        case "l": return .l
        case "m": return .m
        case "n": return .n
        case "o": return .o
        case "p": return .p
        case "q": return .q
        case "r": return .r
        case "s": return .s
        case "t": return .t
        case "u": return .u
        case "v": return .v
        case "w": return .w
        case "x": return .x
        case "y": return .y
        case "z": return .z
        case "1": return .one
        case "2": return .two
        case "3": return .three
        case "4": return .four
        case "5": return .five
        case "6": return .six
        case "7": return .seven
        case "8": return .eight
        case "9": return .nine
        case "0": return .zero
        case "space": return .space
        case "tab": return .tab
        case "escape": return .escape
        case "enter": return .return
        case "return": return .return
        default: return nil
        }
    }
    
    private func intToModifierFlags(_ modifierInt: Int) -> NSEvent.ModifierFlags {
        return NSEvent.ModifierFlags(rawValue: UInt(modifierInt))
    }

    func runTranslation() async {
        let permissions = Permission.checkAllPermissions()
        
        if !permissions.hasAccessibility {
            HUD.showError("Accessibility permission required.\nGrant access in System Settings.")
            Permission.openPrivacyPane(for: .accessibility); playErrorBeep(); return
        }
        
        if !permissions.hasInputMonitoring {
            print("⚠️ Input monitoring permission missing but continuing...")
        }
        
        // Hedef app'i HUD'dan ÖNCE yakala
        let initialFrontmost = NSWorkspace.shared.frontmostApplication
        let target = lastActiveApp ?? initialFrontmost ?? guessTopWindowApp()
        target?.activate(options: []); usleep(250_000)

        // Önce seçili metin dene, yoksa clipboard fallback
        HUD.show("Reading text for translation…")
        let original: String
        let isFromSelection: Bool
        
        // Gelişmiş seçili metin okuma (AX + Cmd+C, clipboard fallback ayara göre)
        let selectionResult = ClipboardHelper.readSelectionStrict(allowClipboardFallback: useClipboardFallback)
        if let selectedText = selectionResult.text, !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            original = selectedText
            isFromSelection = selectionResult.diag.contains("AX:") || selectionResult.diag.contains("Cmd+C:")
        } else {
            // Seçili metin yok, clipboard fallback dene (ayar açıksa)
            if useClipboardFallback {
                HUD.update("No selection found, trying clipboard…")
                let read = ClipboardHelper.readClipboardOnly()
                guard let text = read.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    HUD.showError("No text found.\nSelect text or copy to clipboard."); playErrorBeep(); return
                }
                original = text
                isFromSelection = false
            } else {
                HUD.showError("No text selected.\nSelect text to translate."); playErrorBeep(); return
            }
        }

        // API key kontrolü
        var key = apiKey
        if key.isEmpty, let saved = KeychainHelper.promptAndSave() {
            key = saved
            self.apiKey = saved
        }
        guard !key.isEmpty else {
            playErrorBeep()
            HUD.showError("OpenAI API key required.\nAdd key in Settings.")
            return
        }

        // Translation çağrısı
        HUD.update("Translating \(sourceLanguage) → \(targetLanguage)…")
        let system = buildTranslationPrompt()
        
        do {
            let translated = try await OpenAIClient(apiKey: key).polish(system: system, user: original, model: selectedModel)
            
            // Seçili metinden geldiyse replace et, clipboard'den geldiyse kopyala
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
            HUD.showError("Translation error:\n\((error as NSError).localizedDescription)"); playErrorBeep()
        }
    }

    func runOnce() async {
        let permissions = Permission.checkAllPermissions()
        
        if !permissions.hasAccessibility {
            HUD.showError("Accessibility permission required.\nGrant access in System Settings.")
            Permission.openPrivacyPane(for: .accessibility); playErrorBeep(); return
        }
        
        if !permissions.hasInputMonitoring {
            print("⚠️ Input monitoring permission missing but continuing...")
        }
        // Hedef app'i HUD'dan ÖNCE yakala
        let initialFrontmost = NSWorkspace.shared.frontmostApplication
        let target = lastActiveApp ?? initialFrontmost ?? guessTopWindowApp()
        target?.activate(options: []); usleep(250_000)

        // Önce seçili metin dene, yoksa clipboard fallback
        HUD.show("Reading selection…")
        let original: String
        let isFromSelection: Bool
        
        // Gelişmiş seçili metin okuma (AX + Cmd+C, clipboard fallback ayara göre)
        let selectionResult = ClipboardHelper.readSelectionStrict(allowClipboardFallback: useClipboardFallback)
        if let selectedText = selectionResult.text, !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            original = selectedText
            isFromSelection = selectionResult.diag.contains("AX:") || selectionResult.diag.contains("Cmd+C:")
        } else {
            // Seçili metin yok, clipboard fallback dene (ayar açıksa)
            if useClipboardFallback {
                HUD.update("No selection found, trying clipboard…")
                let read = ClipboardHelper.readClipboardOnly()
                guard let text = read.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    HUD.showError("No text found.\nSelect text or copy to clipboard."); playErrorBeep(); return
                }
                original = text
                isFromSelection = false
            } else {
                HUD.showError("No text selected.\nSelect text to enhance."); playErrorBeep(); return
            }
        }

        // Hangi app'teyiz (Cursor uyarlaması için)
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        self.frontmostBundleID = bundleID

        // API key
        var key = apiKey
        if key.isEmpty, let saved = KeychainHelper.promptAndSave() {
            key = saved
            self.apiKey = saved
        }
        guard !key.isEmpty else {
            playErrorBeep()
            HUD.showError("OpenAI API key required.\nAdd key in Settings.")
            return
        }

        // OpenAI çağrısı (prompt enhancement)
        HUD.update("Enhancing your text…")
        
        let system = buildSystemPrompt(bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier, autoTranslate: autoTranslate, inputText: original)
        print("DEBUG: autoTranslate = \(autoTranslate)")
        print("DEBUG: System prompt contains English instruction: \(system.contains("English"))")
        do {
            let improved = try await OpenAIClient(apiKey: key).polish(system: system, user: original, model: selectedModel)
            
            // Enhancement mode'da clarification kontrolü
            let finalText: String
            if isAIClarificationRequest(improved) {
                finalText = "! " + improved
            } else {
                finalText = improved
            }
            
            // Seçili metinden geldiyse replace et, clipboard'den geldiyse kopyala
            if isFromSelection {
                // Seçili metni değiştirmeyi dene
                let replaced = ClipboardHelper.replaceSelectedText(finalText)
                
                if replaced {
                    HUD.showSuccess("Text replaced successfully")
                } else {
                    // Değiştirme başarısızsa, panoya kopyala ve sonucu göster
                    let copied = ClipboardHelper.writeAndVerify(finalText)
                    if copied {
                        HUD.showSuccess("Text copied to clipboard")
                    } else {
                        HUD.showResult(finalText, title: "Promptify — Result")
                    }
                }
            } else {
                // Clipboard'den geldi: sadece panoya kopyala
                let copied = ClipboardHelper.writeAndVerify(finalText)
                
                if copied {
                    HUD.showSuccess("Text copied to clipboard")
                } else {
                    HUD.showResult(finalText, title: "Promptify — Result")
                }
            }
        } catch {
            HUD.showError("OpenAI error:\n\((error as NSError).localizedDescription)"); playErrorBeep()
        }
    }

    private func detectLanguage(_ text: String) -> String {
        let turkishChars = CharacterSet(charactersIn: "çÇğĞıIİöÖşŞüÜ")
        if text.rangeOfCharacter(from: turkishChars) != nil || 
           text.lowercased().contains("bir") || text.lowercased().contains("bu") || 
           text.lowercased().contains("şey") || text.lowercased().contains("için") {
            return "Turkish"
        }
        return "English"
    }
    
    private func buildSystemPrompt(bundleID: String?, autoTranslate: Bool, inputText: String) -> String {
        let detectedLanguage = detectLanguage(inputText)
        var base = """
        You are a Prompt Enhancement Assistant. Transform the given text into the best possible prompt for AI communication.

        RULES:
        - Fix grammar, spelling, and clarity issues
        - Make instructions specific and actionable  
        - Add necessary context that's clearly implied
        - Use imperative, direct language
        - Structure complex requests with clear steps
        - If you must ask for clarification, do it in the EXACT same language as the input
        - NEVER respond as if you're the AI being prompted - only enhance the prompt itself
        
        ENHANCEMENT FOCUS:
        - If it's a request: Make it more specific and actionable
        - If it's a question: Make it more precise and complete
        - If it's incomplete: Fill in reasonable details based on context
        - If it's vague: Add specificity while preserving intent
        - If the input is too unclear to enhance: Ask for clarification but ALWAYS in the same language as input
        """
        
        if autoTranslate {
            base += """
            
            TRANSLATION RULE:
            - ALWAYS respond in English, regardless of input language
            - Even if asking for clarification, respond in English
            - Translate all responses to English
            """
        } else {
            base += """
            
            LANGUAGE PRESERVATION RULE:
            - You MUST respond in the same language as the input (\(detectedLanguage))
            - NEVER translate to English or any other language
            - This applies to both enhancements AND clarification requests
            - Language preservation is MANDATORY
            """
        }
        
        if let id = bundleID?.lowercased(), id.contains("cursor") {
            base += """
            
            FOR CURSOR IDE CONTEXTS:
            - Structure as step-by-step development tasks
            - Specify exact files/folders when code changes are implied
            - Include technical requirements and constraints
            - Add relevant context about the codebase when helpful
            """
        }
        
        base += """
        
        OUTPUT FORMAT: Return only the enhanced prompt - nothing else.
        """
        
        return base
    }
    
    private func buildTranslationPrompt() -> String {
        return """
        You are a Smart Bidirectional Translation Assistant. 
        
        USER'S PREFERRED LANGUAGES: \(sourceLanguage) ↔ \(targetLanguage)
        
        SMART TRANSLATION LOGIC:
        1. First, detect the language of the input text
        2. If the input is in \(sourceLanguage), translate to \(targetLanguage)
        3. If the input is in \(targetLanguage), translate to \(sourceLanguage)
        4. If the input is in neither language, translate to \(targetLanguage) (default)
        
        TRANSLATION RULES:
        - Provide only the translation, no explanations or language detection notes
        - Maintain the original meaning, tone, and style
        - Use natural, fluent language in the target language
        - Preserve formatting (line breaks, punctuation, etc.)
        - Do not add quotes, prefixes, or suffixes to the translation
        
        EXAMPLES:
        - Input in \(sourceLanguage) → Output in \(targetLanguage)
        - Input in \(targetLanguage) → Output in \(sourceLanguage)
        
        OUTPUT: Only the translated text, nothing else.
        """
    }
    
    private func isAIClarificationRequest(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // İngilizce clarification indicators
        let englishIndicators = [
            "please provide more",
            "could you clarify",
            "i need more information",
            "please specify",
            "what specifically",
            "could you be more specific",
            "i'd need more details",
            "please elaborate"
        ]
        
        // Türkçe clarification indicators
        let turkishIndicators = [
            "daha fazla bilgi",
            "lütfen açıklayın",
            "daha spesifik",
            "detay verebilir",
            "hangi konuda",
            "ne hakkında",
            "daha detaylı",
            "netleştir"
        ]
        
        for indicator in englishIndicators + turkishIndicators {
            if lowercased.contains(indicator) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Dock Visibility
    private func updateDockVisibility() {
        DispatchQueue.main.async {
            if self.hideFromDock {
                NSApp.setActivationPolicy(.accessory)
                print("🫥 App hidden from dock")
            } else {
                NSApp.setActivationPolicy(.regular)
                print("👁️ App visible in dock")
            }
        }
    }
    
    // MARK: - Speech to Text Toggle Setup
    func setupSpeechToTextToggle() {
        print("🎤 Setting up speech to text toggle monitoring...")
        
        // Remove existing monitor if any
        if let monitor = speechToTextToggleMonitor {
            print("🎤 Removing existing speech to text toggle monitor")
            NSEvent.removeMonitor(monitor)
            speechToTextToggleMonitor = nil
        }
        
        // Only set up monitoring if speech to text toggle is enabled
        guard speechToTextToggleEnabled else {
            print("🎤 Speech to text toggle is disabled, not setting up monitoring")
            return
        }
        
        // Map toggle key to key code
        let keyCode = getKeyCodeForToggleKey(speechToTextToggleKey)
        print("🎤 Speech to text toggle key code: \(keyCode) for key: \(speechToTextToggleKey)")
        
        // Add global monitor for key events
        speechToTextToggleMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged],
            handler: { [weak self] event in
                self?.handleSpeechToTextToggleEvent(event, keyCode: keyCode)
            }
        )
        
        print("🎤 Speech to text toggle monitoring started with key: \(speechToTextToggleKey), keyCode: \(keyCode)")
    }
    
    private func getKeyCodeForToggleKey(_ key: String) -> UInt16 {
        print("🎤 Getting key code for toggle key: \(key)")
        let keyCode: UInt16
        switch key {
        case "left_cmd":
            keyCode = 55  // Left Command key code
        case "right_cmd":
            keyCode = 54  // Right Command key code
        case "left_opt":
            keyCode = 58  // Left Option key code
        case "right_opt":
            keyCode = 61  // Right Option key code
        case "left_ctrl":
            keyCode = 59  // Left Control key code
        case "right_ctrl":
            keyCode = 62  // Right Control key code
        case "left_shift":
            keyCode = 56  // Left Shift key code
        case "right_shift":
            keyCode = 60  // Right Shift key code
        case "fn":
            keyCode = 63  // Fn key code
        case "space":
            keyCode = 49  // Space bar key code
        default:
            keyCode = 55  // Default to left Command
        }
        print("🎤 Key code for \(key): \(keyCode)")
        return keyCode
    }
    
    private func handleSpeechToTextToggleEvent(_ event: NSEvent, keyCode: UInt16) {
        print("🎤 Speech to text toggle event received: type=\(event.type), keyCode=\(event.keyCode), expectedKeyCode=\(keyCode), modifierFlags=\(event.modifierFlags)")
        
        // Only process if speech to text toggle is enabled
        guard speechToTextToggleEnabled else { 
            print("🎤 Speech to text toggle is disabled")
            return 
        }
        
        // Note: We removed the early return check here so toggle can work to stop recording too
        
        var shouldToggle = false
        
        // Handle events based on key type
        if event.keyCode == keyCode {
            if isModifierKey(keyCode) && event.type == .flagsChanged {
                // For modifier keys, check actual key press via keyCode match
                let currentPressed = event.modifierFlags.contains(getModifierFlagForKeyCode(keyCode))
                let wasPressed = lastModifierFlags.contains(getModifierFlagForKeyCode(keyCode))
                
                print("🎤 Modifier key \(keyCode) flagsChanged: currentPressed=\(currentPressed), wasPressed=\(wasPressed)")
                
                // Only toggle when the SPECIFIC key state changes from not pressed to pressed
                if currentPressed && !wasPressed {
                    print("🎤 Specific modifier key pressed (state changed), should toggle")
                    shouldToggle = true
                }
                
                // Update last modifier flags
                lastModifierFlags = event.modifierFlags
            } else if !isModifierKey(keyCode) && event.type == .keyDown {
                // For regular keys, toggle on keyDown
                print("🎤 Regular key \(keyCode) pressed")
                shouldToggle = true
            }
        }
        
        if shouldToggle {
            print("🎤 Toggling speech to text recording...")
            Task { @MainActor in
                await self.voiceRecordingManager.toggleSpeechToTextRecording()
            }
        }
    }
    
    private func isModifierKey(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case 54, 55: // Right/Left Command
            return true
        case 58, 61: // Left/Right Option
            return true
        case 59, 62: // Left/Right Control
            return true
        case 56, 60: // Left/Right Shift
            return true
        case 63: // Fn key
            return true
        default:
            return false
        }
    }
    
    private func isModifierKeyPressed(_ keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        switch keyCode {
        case 54, 55: // Command keys
            return modifierFlags.contains(.command)
        case 58, 61: // Option keys
            return modifierFlags.contains(.option)
        case 59, 62: // Control keys
            return modifierFlags.contains(.control)
        case 56, 60: // Shift keys
            return modifierFlags.contains(.shift)
        case 63: // Fn key
            return modifierFlags.contains(.function)
        default:
            return false
        }
    }
    
    private func getModifierFlagForKeyCode(_ keyCode: UInt16) -> NSEvent.ModifierFlags {
        switch keyCode {
        case 54, 55: // Command keys (left and right)
            return .command
        case 58, 61: // Option keys (left and right)
            return .option
        case 59, 62: // Control keys (left and right)
            return .control
        case 56, 60: // Shift keys (left and right)
            return .shift
        case 63: // Fn key
            return .function
        default:
            return []
        }
    }
    
    
    // MARK: - Launch at Login
    /// Play error beep if audio feedback is enabled
    private func playErrorBeep() {
        if enableAudioFeedback {
            playErrorBeep()
        }
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        
        if enabled {
            // Add to login items
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled) {
                print("Launch at login enabled")
            } else {
                print("Failed to enable launch at login")
            }
        } else {
            // Remove from login items
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled) {
                print("Launch at login disabled")
            } else {
                print("Failed to disable launch at login")
            }
        }
    }
}