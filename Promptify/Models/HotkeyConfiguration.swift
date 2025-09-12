import Foundation
import SwiftUI
import HotKey

/// Hotkey configuration and management
@MainActor
final class HotkeyConfiguration: ObservableObject {
    @Published var customHotkeyKey = UserDefaults.standard.string(forKey: "customHotkeyKey") ?? "k" {
        didSet { 
            UserDefaults.standard.set(customHotkeyKey, forKey: "customHotkeyKey")
            setupHotkey()
        }
    }
    @Published var customHotkeyModifiers = UserDefaults.standard.integer(forKey: "customHotkeyModifiers") {
        didSet { 
            UserDefaults.standard.set(customHotkeyModifiers, forKey: "customHotkeyModifiers")
            setupHotkey()
        }
    }
    
    @Published var translationEnabled = UserDefaults.standard.bool(forKey: "translationEnabled") {
        didSet { 
            UserDefaults.standard.set(translationEnabled, forKey: "translationEnabled")
            setupTranslationHotkey()
        }
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
    
    private var hotKey: HotKey?
    private var translationHotKey: HotKey?
    private var voiceEnhancementHotKey: HotKey?
    private var voiceTranslationHotKey: HotKey?
    
    weak var appState: AppState?
    
    init() {
        setupDefaultsIfNeeded()
    }
    
    func configure(with appState: AppState) {
        self.appState = appState
        setupAllHotkeys()
    }
    
    private func setupDefaultsIfNeeded() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            UserDefaults.standard.set("k", forKey: "customHotkeyKey")
            UserDefaults.standard.set(Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue), forKey: "customHotkeyModifiers")
            UserDefaults.standard.set(false, forKey: "translationEnabled")
            UserDefaults.standard.set("t", forKey: "translationHotkeyKey")
            UserDefaults.standard.set(Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue), forKey: "translationHotkeyModifiers")
            UserDefaults.standard.set("e", forKey: "voiceEnhancementHotkeyKey")
            UserDefaults.standard.set(Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue), forKey: "voiceEnhancementHotkeyModifiers")
            UserDefaults.standard.set("r", forKey: "voiceTranslationHotkeyKey")
            UserDefaults.standard.set(Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue), forKey: "voiceTranslationHotkeyModifiers")
            
            customHotkeyKey = "k"
            customHotkeyModifiers = Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue)
            translationEnabled = false
            translationHotkeyKey = "t"
            translationHotkeyModifiers = Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue)
            voiceEnhancementHotkeyKey = "e"
            voiceEnhancementHotkeyModifiers = Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
            voiceTranslationHotkeyKey = "r"
            voiceTranslationHotkeyModifiers = Int(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        }
    }
    
    private func setupAllHotkeys() {
        setupHotkey()
        setupTranslationHotkey()
        setupVoiceEnhancementHotkey()
        setupVoiceTranslationHotkey()
    }
    
    private func setupHotkey() {
        hotKey = nil
        
        guard let keyCode = keyStringToKeyCode(customHotkeyKey) else { return }
        let modifierFlags = intToModifierFlags(customHotkeyModifiers)
        
        hotKey = HotKey(key: keyCode, modifiers: modifierFlags)
        hotKey?.keyDownHandler = { [weak self] in
            guard let self = self, let appState = self.appState else { return }
            Task { await appState.runOnce() }
        }
    }
    
    private func setupTranslationHotkey() {
        translationHotKey = nil
        
        guard translationEnabled else { return }
        guard let keyCode = keyStringToKeyCode(translationHotkeyKey) else { return }
        let modifierFlags = intToModifierFlags(translationHotkeyModifiers)
        
        translationHotKey = HotKey(key: keyCode, modifiers: modifierFlags)
        translationHotKey?.keyDownHandler = { [weak self] in
            guard let self = self, let appState = self.appState else { return }
            Task { await appState.runTranslation() }
        }
    }
    
    private func setupVoiceEnhancementHotkey() {
        if let existingHotKey = voiceEnhancementHotKey {
            print("Removing existing voice enhancement hotkey")
        }
        voiceEnhancementHotKey = nil
        
        guard !voiceEnhancementHotkeyKey.isEmpty else { 
            print("Voice enhancement hotkey not set")
            return 
        }
        
        guard let keyCode = keyStringToKeyCode(voiceEnhancementHotkeyKey) else { 
            print("Invalid voice enhancement hotkey: \(voiceEnhancementHotkeyKey)")
            return 
        }
        
        var modifierFlags = intToModifierFlags(voiceEnhancementHotkeyModifiers)
        
        if modifierFlags.isEmpty {
            modifierFlags = [.command, .shift]
            voiceEnhancementHotkeyModifiers = Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
            print("No modifiers set for voice enhancement hotkey, defaulting to Command+Shift")
        }
        
        print("Setting up voice enhancement hotkey: \(voiceEnhancementHotkeyKey) with modifiers: \(modifierFlags)")
        
        do {
            voiceEnhancementHotKey = HotKey(key: keyCode, modifiers: modifierFlags)
            voiceEnhancementHotKey?.keyDownHandler = { [weak self] in
                guard let self = self, let appState = self.appState else { return }
                print("Voice enhancement hotkey pressed!")
                Task { await appState.voiceRecordingManager.toggleRecording(mode: .enhancement) }
            }
            print("Voice enhancement hotkey successfully registered")
        } catch {
            print("Failed to register voice enhancement hotkey: \(error)")
        }
    }
    
    private func setupVoiceTranslationHotkey() {
        if let existingHotKey = voiceTranslationHotKey {
            print("Removing existing voice translation hotkey")
        }
        voiceTranslationHotKey = nil
        
        guard !voiceTranslationHotkeyKey.isEmpty else { 
            print("Voice translation hotkey not set")
            return 
        }
        
        guard let keyCode = keyStringToKeyCode(voiceTranslationHotkeyKey) else { 
            print("Invalid voice translation hotkey: \(voiceTranslationHotkeyKey)")
            return 
        }
        
        var modifierFlags = intToModifierFlags(voiceTranslationHotkeyModifiers)
        
        if modifierFlags.isEmpty {
            modifierFlags = [.command, .shift]
            voiceTranslationHotkeyModifiers = Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
            print("No modifiers set for voice translation hotkey, defaulting to Command+Shift")
        }
        
        print("Setting up voice translation hotkey: \(voiceTranslationHotkeyKey) with modifiers: \(modifierFlags)")
        
        do {
            voiceTranslationHotKey = HotKey(key: keyCode, modifiers: modifierFlags)
            voiceTranslationHotKey?.keyDownHandler = { [weak self] in
                guard let self = self, let appState = self.appState else { return }
                print("Voice translation hotkey pressed!")
                Task { await appState.voiceRecordingManager.toggleRecording(mode: .translation) }
            }
            print("Voice translation hotkey successfully registered")
        } catch {
            print("Failed to register voice translation hotkey: \(error)")
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
}