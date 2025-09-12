import Foundation
import SwiftUI

/// App-wide configuration and user defaults management
@MainActor
final class AppConfiguration: ObservableObject {
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
    
    init() {
        setupDefaultsIfNeeded()
    }
    
    private func setupDefaultsIfNeeded() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "autoTranslate")
            UserDefaults.standard.set(true, forKey: "launchAtLogin")
            UserDefaults.standard.set("gpt-3.5-turbo", forKey: "selectedModel")
            UserDefaults.standard.set(true, forKey: "useClipboardFallback")
            UserDefaults.standard.set(true, forKey: "enableAudioFeedback")
            UserDefaults.standard.set(false, forKey: "hideFromDock")
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            
            autoTranslate = true
            launchAtLogin = true
            hideFromDock = false
            selectedModel = "gpt-3.5-turbo"
            useClipboardFallback = true
            enableAudioFeedback = true
        }
    }
    
    private func updateDockVisibility() {
        DispatchQueue.main.async {
            if self.hideFromDock {
                NSApp.setActivationPolicy(.accessory)
                print("App hidden from dock")
            } else {
                NSApp.setActivationPolicy(.regular)
                print("App visible in dock")
            }
        }
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        
        if enabled {
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled) {
                print("Launch at login enabled")
            } else {
                print("Failed to enable launch at login")
            }
        } else {
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled) {
                print("Launch at login disabled")
            } else {
                print("Failed to disable launch at login")
            }
        }
    }
}