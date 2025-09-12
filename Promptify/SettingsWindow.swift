import SwiftUI
import AppKit
import Foundation

class SettingsWindowManager: ObservableObject {
    private var settingsWindow: NSWindow?
    
    func showSettings(_ appState: AppState, _ updateManager: UpdateManager) {
        if settingsWindow == nil {
            let settingsView = SettingsView(appState: appState, updateManager: updateManager) {
                self.closeSettings()
            }
            
            let hostingView = NSHostingView(rootView: settingsView)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 780),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            settingsWindow?.title = "Promptify Settings"
            settingsWindow?.contentView = hostingView
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
            
            // Configure window to not terminate app when closed
            settingsWindow?.delegate = nil
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeSettings() {
        settingsWindow?.close()
        settingsWindow = nil
    }
}


struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var updateManager: UpdateManager
    let onClose: () -> Void
    
    @State private var tempApiKey: String = ""
    @State private var showingApiKey = false
    @State private var selectedTab = 0
    
    // Add state for permissions
    @State private var hasAccessibility = Permission.hasAccessibility
    @State private var hasInputMonitoring = Permission.hasInputMonitoring()
    @State private var hasMicrophone = Permission.hasMicrophone
    @State private var permissionTimer: Timer?
    
    // Auto-update service
    @StateObject private var autoUpdateService = AutoUpdateService(updateManager: UpdateManager())
    @StateObject private var progressWindowManager = UpdateProgressWindowManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Promptify Settings")
                    .font(.title2)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.bottom, 10)
            
            // Tab Selector
            Picker("", selection: $selectedTab) {
                Text("General").tag(0)
                Text("Enhancement").tag(1)
                Text("Translation").tag(2)
                Text("Voice").tag(3)
                Text("Diagnostics").tag(4)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
            
            // Tab Content
            if selectedTab == 0 {
                generalTab
            } else if selectedTab == 1 {
                controlsEnhancementTab
            } else if selectedTab == 2 {
                translationTab
            } else if selectedTab == 3 {
                voiceRecordingTab
            } else {
                diagnosticsTab
            }
            
            Spacer()
            
            // Footer with Permissions
            VStack(spacing: 10) {
                permissionSection
            }
        }
        .padding(24)
        .frame(width: 520, height: 680)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.hasAccessibility = Permission.hasAccessibility
                self.hasInputMonitoring = Permission.hasInputMonitoring()
                self.hasMicrophone = Permission.hasMicrophone
                print("🔄 Permissions refreshed on app focus")
            }
        }
        .onAppear {
            // Update permissions when view appears
            self.hasAccessibility = Permission.hasAccessibility
            self.hasInputMonitoring = Permission.hasInputMonitoring()
            self.hasMicrophone = Permission.hasMicrophone
            print("🔄 Permissions loaded on view appear")
            
            // Start permission monitoring timer
            self.permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                let newAccessibility = Permission.hasAccessibility
                let newInputMonitoring = Permission.hasInputMonitoring()
                let newMicrophone = Permission.hasMicrophone
                
                if newAccessibility != self.hasAccessibility || 
                   newInputMonitoring != self.hasInputMonitoring || 
                   newMicrophone != self.hasMicrophone {
                    
                    DispatchQueue.main.async {
                        self.hasAccessibility = newAccessibility
                        self.hasInputMonitoring = newInputMonitoring
                        self.hasMicrophone = newMicrophone
                        print("🔄 Permission status changed - A:\(newAccessibility) I:\(newInputMonitoring) M:\(newMicrophone)")
                    }
                }
            }
        }
        .onDisappear {
            // Stop timer when view disappears
            self.permissionTimer?.invalidate()
            self.permissionTimer = nil
        }
    }
    
    var permissionSection: some View {
        VStack(spacing: 12) {
            // Header with refresh button
            HStack {
                Text("Permissions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    self.hasAccessibility = Permission.hasAccessibility
                    self.hasInputMonitoring = Permission.hasInputMonitoring()
                    self.hasMicrophone = Permission.hasMicrophone
                    print("🔄 Manual permission refresh")
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Refresh permission status")
            }
            .padding(.bottom, 8)
            // Accessibility Permission
            HStack {
                Text("Accessibility")
                    .font(.headline)
                Spacer()
                if hasAccessibility {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Enabled")
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Not Enabled")
                        Spacer()
                        Button("Grant Access") {
                            Permission.openPrivacyPane(for: .accessibility)
                            // Schedule a refresh check after user potentially grants permission
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.hasAccessibility = Permission.hasAccessibility
                                print("🔄 Accessibility permission refreshed after grant attempt")
                            }
                        }
                    }
                }
            }
            
            // Input Monitoring Permission
            HStack {
                Text("Input Monitoring")
                    .font(.headline)
                Spacer()
                if hasInputMonitoring {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Enabled")
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Not Enabled")
                        Spacer()
                        Button("Grant Access") {
                            Permission.openPrivacyPane(for: .inputMonitoring)
                            // Schedule a refresh check after user potentially grants permission
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.hasInputMonitoring = Permission.hasInputMonitoring()
                                print("🔄 Input monitoring permission refreshed after grant attempt")
                            }
                        }
                    }
                }
            }
            
            // Microphone Permission
            HStack {
                Text("Microphone Access")
                    .font(.headline)
                Spacer()
                if hasMicrophone {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Enabled")
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Not Enabled")
                        Spacer()
                        Button("Grant Access") {
                            Permission.openPrivacyPane(for: .microphone)
                            // Schedule a refresh check after user potentially grants permission
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.hasMicrophone = Permission.hasMicrophone
                                print("🔄 Microphone permission refreshed after grant attempt")
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }

    
    var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // AI Model Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Model")
                        .font(.headline)
                    
                    Picker("", selection: $appState.selectedModel) {
                        Text("GPT-3.5 Turbo (Fast & Cheap)").tag("gpt-3.5-turbo")
                        Text("GPT-4 (Better Quality)").tag("gpt-4")
                        Text("GPT-4 Turbo").tag("gpt-4-turbo-preview")
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                
                // API Key Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.headline)
                    
                    HStack {
                        if showingApiKey {
                            SecureField("sk-...", text: $tempApiKey)
                                .textFieldStyle(.roundedBorder)
                                .onAppear {
                                    tempApiKey = appState.apiKey
                                }
                        } else {
                            HStack {
                                Text(appState.apiKey.isEmpty ? "Not set" : "••••••••••••••••")
                                    .foregroundColor(appState.apiKey.isEmpty ? .secondary : .primary)
                                Spacer()
                            }
                            .frame(height: 22)
                            .padding(.horizontal, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                        }
                        
                        Button(showingApiKey ? "Save" : "Edit") {
                            if showingApiKey {
                                appState.apiKey = tempApiKey
                                KeychainHelper.save(apiKey: tempApiKey)
                            }
                            showingApiKey.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        if showingApiKey {
                            Button("Cancel") {
                                tempApiKey = appState.apiKey
                                showingApiKey = false
                            }
                            .controlSize(.small)
                        }
                    }
                    
                    if !appState.apiKey.isEmpty {
                        Button("Clear API Key") {
                            appState.apiKey = ""
                            tempApiKey = ""
                            KeychainHelper.delete()
                            showingApiKey = false
                        }
                        .foregroundColor(.red)
                        .controlSize(.small)
                    }
                    
                    Text("Get your API key from OpenAI Platform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // General Settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("General")
                        .font(.headline)
                    
                    Toggle("Launch at login", isOn: $appState.launchAtLogin)
                        .help("Automatically start Promptify when you log in to macOS")
                    
                    Toggle("Hide from Dock", isOn: $appState.hideFromDock)
                        .help("Run as menu bar only app - hide icon from Dock like Health Doctor and other menu bar apps")
                    
                    Toggle("Use clipboard as fallback", isOn: $appState.useClipboardFallback)
                        .help("If no text is selected, use clipboard content as fallback for processing.")
                    
                    Toggle("Enable audio feedback", isOn: $appState.enableAudioFeedback)
                        .help("Play sounds for recording start/stop, completion notifications, and other audio cues throughout the app.")
                }
                
                Divider()
                
                // Updates Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Updates")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if updateManager.hasUpdate {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("New version available: v\(updateManager.latestVersion)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            } else if !updateManager.isCheckingForUpdates {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("You're up to date")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        if updateManager.hasUpdate {
                            Button("Update Now") {
                                updateManager.downloadAndInstallUpdate()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        } else {
                            Button(updateManager.isCheckingForUpdates ? "Checking..." : "Check for Updates") {
                                Task {
                                    await updateManager.checkForUpdates()
                                }
                            }
                            .disabled(updateManager.isCheckingForUpdates)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(.top, 1)
        }
    }
    
    var controlsEnhancementTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hotkey Settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Shortcut")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enhance Prompt:")
                        
                        HotkeyRecorder(
                            key: $appState.customHotkeyKey,
                            modifiers: $appState.customHotkeyModifiers
                        )
                        .frame(height: 34)
                        .frame(maxWidth: .infinity)
                        
                        Text("Click the field above and press your desired shortcut")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Enhancement Settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt Enhancement")
                        .font(.headline)
                    
                    Toggle("Auto-translate to English", isOn: $appState.autoTranslate)
                        .help("Always output enhanced prompts in English regardless of input language")
                }
            }
            .padding(.top, 1)
        }
    }
    
    var translationTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Translation Toggle
                VStack(alignment: .leading, spacing: 8) {
                    Text("Translation")
                        .font(.headline)
                    
                    Toggle("Enable translation", isOn: $appState.translationEnabled)
                        .help("Add translation capability with separate hotkey")
                }
                
                if appState.translationEnabled {
                    Divider()
                    
                    // Language Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Languages")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            HStack {
                                Text("From:")
                                Picker("", selection: $appState.sourceLanguage) {
                                    Text("🇹🇷 Turkish").tag("Turkish")
                                    Text("🇺🇸 English").tag("English")
                                    Text("🇩🇪 German").tag("German")
                                    Text("🇫🇷 French").tag("French")
                                    Text("🇪🇸 Spanish").tag("Spanish")
                                    Text("🇮🇹 Italian").tag("Italian")
                                    Text("🇵🇹 Portuguese").tag("Portuguese")
                                    Text("🇷🇺 Russian").tag("Russian")
                                    Text("🇨🇳 Chinese").tag("Chinese")
                                    Text("🇯🇵 Japanese").tag("Japanese")
                                    Text("🇰🇷 Korean").tag("Korean")
                                    Text("🇦🇪 Arabic").tag("Arabic")
                                    Text("🇮🇳 Hindi").tag("Hindi")
                                    Text("🇳🇱 Dutch").tag("Dutch")
                                    Text("🇸🇪 Swedish").tag("Swedish")
                                    Text("🇳🇴 Norwegian").tag("Norwegian")
                                    Text("🇩🇰 Danish").tag("Danish")
                                    Text("🇫🇮 Finnish").tag("Finnish")
                                    Text("🇬🇷 Greek").tag("Greek")
                                    Text("🇵🇱 Polish").tag("Polish")
                                    Text("🇨🇿 Czech").tag("Czech")
                                    Text("🇭🇺 Hungarian").tag("Hungarian")
                                    Text("🇷🇴 Romanian").tag("Romanian")
                                    Text("🇧🇬 Bulgarian").tag("Bulgarian")
                                    Text("🇭🇷 Croatian").tag("Croatian")
                                    Text("🇸🇰 Slovak").tag("Slovak")
                                    Text("🇸🇮 Slovenian").tag("Slovenian")
                                    Text("🇱🇹 Lithuanian").tag("Lithuanian")
                                    Text("🇱🇻 Latvian").tag("Latvian")
                                    Text("🇪🇪 Estonian").tag("Estonian")
                                    Text("🇺🇦 Ukrainian").tag("Ukrainian")
                                    Text("🇧🇾 Belarusian").tag("Belarusian")
                                    Text("🇰🇿 Kazakh").tag("Kazakh")
                                    Text("🇺🇿 Uzbek").tag("Uzbek")
                                    Text("🇦🇿 Azerbaijani").tag("Azerbaijani")
                                    Text("🇦🇲 Armenian").tag("Armenian")
                                    Text("🇬🇪 Georgian").tag("Georgian")
                                    Text("🇮🇱 Hebrew").tag("Hebrew")
                                    Text("🇮🇷 Persian").tag("Persian")
                                    Text("🇹🇭 Thai").tag("Thai")
                                    Text("🇻🇳 Vietnamese").tag("Vietnamese")
                                    Text("🇮🇩 Indonesian").tag("Indonesian")
                                    Text("🇲🇾 Malay").tag("Malay")
                                    Text("🇵🇭 Filipino").tag("Filipino")
                                }
                                .pickerStyle(.menu)
                                .frame(minWidth: 140)
                            }
                            
                            HStack {
                                Text("To:")
                                Picker("", selection: $appState.targetLanguage) {
                                    Text("🇺🇸 English").tag("English")
                                    Text("🇹🇷 Turkish").tag("Turkish")
                                    Text("🇩🇪 German").tag("German")
                                    Text("🇫🇷 French").tag("French")
                                    Text("🇪🇸 Spanish").tag("Spanish")
                                    Text("🇮🇹 Italian").tag("Italian")
                                    Text("🇵🇹 Portuguese").tag("Portuguese")
                                    Text("🇷🇺 Russian").tag("Russian")
                                    Text("🇨🇳 Chinese").tag("Chinese")
                                    Text("🇯🇵 Japanese").tag("Japanese")
                                    Text("🇰🇷 Korean").tag("Korean")
                                    Text("🇦🇪 Arabic").tag("Arabic")
                                    Text("🇮🇳 Hindi").tag("Hindi")
                                    Text("🇳🇱 Dutch").tag("Dutch")
                                    Text("🇸🇪 Swedish").tag("Swedish")
                                    Text("🇳🇴 Norwegian").tag("Norwegian")
                                    Text("🇩🇰 Danish").tag("Danish")
                                    Text("🇫🇮 Finnish").tag("Finnish")
                                    Text("🇬🇷 Greek").tag("Greek")
                                    Text("🇵🇱 Polish").tag("Polish")
                                    Text("🇨🇿 Czech").tag("Czech")
                                    Text("🇭🇺 Hungarian").tag("Hungarian")
                                    Text("🇷🇴 Romanian").tag("Romanian")
                                    Text("🇧🇬 Bulgarian").tag("Bulgarian")
                                    Text("🇭🇷 Croatian").tag("Croatian")
                                    Text("🇸🇰 Slovak").tag("Slovak")
                                    Text("🇸🇮 Slovenian").tag("Slovenian")
                                    Text("🇱🇹 Lithuanian").tag("Lithuanian")
                                    Text("🇱🇻 Latvian").tag("Latvian")
                                    Text("🇪🇪 Estonian").tag("Estonian")
                                    Text("🇺🇦 Ukrainian").tag("Ukrainian")
                                    Text("🇧🇾 Belarusian").tag("Belarusian")
                                    Text("🇰🇿 Kazakh").tag("Kazakh")
                                    Text("🇺🇿 Uzbek").tag("Uzbek")
                                    Text("🇦🇿 Azerbaijani").tag("Azerbaijani")
                                    Text("🇦🇲 Armenian").tag("Armenian")
                                    Text("🇬🇪 Georgian").tag("Georgian")
                                    Text("🇮🇱 Hebrew").tag("Hebrew")
                                    Text("🇮🇷 Persian").tag("Persian")
                                    Text("🇹🇭 Thai").tag("Thai")
                                    Text("🇻🇳 Vietnamese").tag("Vietnamese")
                                    Text("🇮🇩 Indonesian").tag("Indonesian")
                                    Text("🇲🇾 Malay").tag("Malay")
                                    Text("🇵🇭 Filipino").tag("Filipino")
                                }
                                .pickerStyle(.menu)
                                .frame(minWidth: 140)
                            }
                        }
                    }
                    
                    Divider()
                    
                    Divider()
                    
                    // Translation Hotkey Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Translation Shortcut")
                            .font(.headline)
                        
                        HotkeyRecorder(
                            key: $appState.translationHotkeyKey,
                            modifiers: $appState.translationHotkeyModifiers
                        )
                        .frame(height: 34)
                        .frame(maxWidth: .infinity)
                        
                        Text("Click the field above and press your desired shortcut for translation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 1)
        }
    }
    
    var voiceRecordingTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Voice Recording Settings")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Configure voice input for prompt enhancement and translation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Voice to Text Toggle Mode
                VStack(alignment: .leading, spacing: 12) {
                    Text("Voice to Text Toggle Mode")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Single Toggle Recording")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Use a single key toggle for quick voice to text conversion")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Toggle("Enable Voice to Text Toggle", isOn: $appState.speechToTextToggleEnabled)
                            .padding(.top, 4)
                        
                        if appState.speechToTextToggleEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Toggle Key:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                // Predefined toggle keys
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Select a key for voice to text toggle:")
                                        .font(.caption)
                                    
                                    Picker("", selection: $appState.speechToTextToggleKey) {
                                        Text("Left Command (⌘)").tag("left_cmd")
                                        Text("Right Command (⌘)").tag("right_cmd")
                                        Text("Left Option (⌥)").tag("left_opt")
                                        Text("Right Option (⌥)").tag("right_opt")
                                        Text("Left Control (⌃)").tag("left_ctrl")
                                        Text("Right Control (⌃)").tag("right_ctrl")
                                        Text("Left Shift (⇧)").tag("left_shift")
                                        Text("Right Shift (⇧)").tag("right_shift")
                                        Text("Fn Key").tag("fn")
                                        Text("Space Bar").tag("space")
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity)
                                    
                                    Text("Press once to start recording, press again to stop. No need to hold the key.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                Divider()
                
                
                
                // Voice Enhancement Mode
                VStack(alignment: .leading, spacing: 12) {
                    Text("Voice Enhanced Prompts")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voice Enhancement")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Voice will be transcribed and then enhanced using AI before copying to clipboard")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shortcut:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HotkeyRecorder(
                                key: $appState.voiceEnhancementHotkeyKey,
                                modifiers: $appState.voiceEnhancementHotkeyModifiers
                            )
                            .frame(height: 34)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                Divider()
                
                // Voice Translation Mode
                VStack(alignment: .leading, spacing: 12) {
                    Text("Voice Translation")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voice Translation")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Voice will be transcribed and then translated between your configured languages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shortcut:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HotkeyRecorder(
                                key: $appState.voiceTranslationHotkeyKey,
                                modifiers: $appState.voiceTranslationHotkeyModifiers
                            )
                            .frame(height: 34)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                Divider()
                
                // Usage Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to Use")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Text("1.")
                                .fontWeight(.medium)
                            Text("Press your assigned shortcut to start recording")
                        }
                        
                        HStack(alignment: .top) {
                            Text("2.")
                                .fontWeight(.medium)
                            Text("Speak your text clearly")
                        }
                        
                        HStack(alignment: .top) {
                            Text("3.")
                                .fontWeight(.medium)
                            Text("Press the shortcut again to stop and process")
                        }
                        
                        HStack(alignment: .top) {
                            Text("4.")
                                .fontWeight(.medium)
                            Text("The result will be copied to clipboard or displayed")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.top, 1)
        }
    }
    
    var diagnosticsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Permission Diagnostics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Permission Diagnostics")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("If you're experiencing permission issues, use these tools to diagnose and fix problems.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Button("🔍 Run Permission Diagnostic") {
                            let _ = PermissionDiagnostic.performDiagnostic()
                            
                            let alert = NSAlert()
                            alert.messageText = "Permission Diagnostic Complete"
                            alert.informativeText = "Check the console output for detailed results. If issues persist, try the reset option below."
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button("🧹 Reset Permission State") {
                            let alert = NSAlert()
                            alert.messageText = "Reset Permission State"
                            alert.informativeText = "This will clear all cached permission states and force fresh checks. You may need to re-grant permissions. Continue?"
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "Reset")
                            alert.addButton(withTitle: "Cancel")
                            
                            if alert.runModal() == .alertFirstButtonReturn {
                                PermissionDiagnostic.resetPermissionState()
                                
                                // Refresh permission states
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.hasAccessibility = Permission.hasAccessibility
                                    self.hasInputMonitoring = Permission.hasInputMonitoring()
                                    self.hasMicrophone = Permission.hasMicrophone
                                }
                                
                                let successAlert = NSAlert()
                                successAlert.messageText = "Permission State Reset"
                                successAlert.informativeText = "Permission cache has been cleared. Please check the permissions section below and re-grant any missing permissions."
                                successAlert.addButton(withTitle: "OK")
                                successAlert.runModal()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                Divider()
                
                // Update Management
                VStack(alignment: .leading, spacing: 12) {
                    Text("Update Management")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Version:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        if updateManager.hasUpdate {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Update Available:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("v\(updateManager.latestVersion)")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Button(updateManager.isCheckingForUpdates ? "🔄 Checking..." : "🔍 Check for Updates") {
                            Task {
                                await updateManager.checkForUpdates(performCleanup: true)
                            }
                        }
                        .disabled(updateManager.isCheckingForUpdates)
                        .frame(maxWidth: .infinity)
                        
                        if updateManager.hasUpdate {
                            Button(autoUpdateService.isUpdating ? "🔄 Installing..." : "🚀 Install Update Automatically") {
                                progressWindowManager.showUpdateProgress(autoUpdateService)
                                Task {
                                    await autoUpdateService.performAutomaticUpdate()
                                }
                            }
                            .disabled(autoUpdateService.isUpdating)
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.borderedProminent)
                            
                            Button("📥 Manual Download") {
                                updateManager.openLatestRelease()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    
                    if autoUpdateService.isUpdating {
                        VStack(spacing: 4) {
                            ProgressView("Installing update...", value: autoUpdateService.updateProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            Text(autoUpdateService.updateStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                Divider()
                
                // Settings Management
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings Management")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Backup and restore your app settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Button("💾 Backup Settings") {
                            SettingsMigrator.createBackup()
                            
                            let alert = NSAlert()
                            alert.messageText = "Settings Backed Up"
                            alert.informativeText = "Your current settings have been backed up. They will be automatically restored if needed during updates."
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button("🔧 Validate & Fix Settings") {
                            SettingsMigrator.validateAndFixSettings()
                            
                            let alert = NSAlert()
                            alert.messageText = "Settings Validation Complete"
                            alert.informativeText = "Your settings have been validated and any issues have been fixed."
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button("🧹 Clean Up Old Settings") {
                            SettingsMigrator.cleanupDeprecatedSettings()
                            
                            let alert = NSAlert()
                            alert.messageText = "Cleanup Complete"
                            alert.informativeText = "Deprecated settings have been removed from your system."
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                Divider()
                
                // System Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("System Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("macOS Version:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(ProcessInfo.processInfo.operatingSystemVersionString)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Bundle ID:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(Bundle.main.bundleIdentifier ?? "Unknown")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Build Number:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding(.top, 1)
        }
    }
    
}
