import SwiftUI
import ApplicationServices

// Shared instances for app-wide access
@MainActor
class AppInstances: ObservableObject {
    static let shared = AppInstances()
    
    @Published var appState: AppState
    @Published var settingsManager: SettingsWindowManager
    @Published var updateManager: UpdateManager
    
    private init() {
        self.appState = AppState()
        self.settingsManager = SettingsWindowManager()
        self.updateManager = UpdateManager()
    }
}

@main
struct PromptifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var instances = AppInstances.shared

    init() {
        Permission.ensurePermissionsAtLaunch()
    }

    var body: some Scene {

        MenuBarExtra("Promptify", image: "MenuBarIcon") {
            VStack(alignment: .leading, spacing: 8) {
                // Quick run button
                Button("Enhance Prompt (⌥⌘K)") { 
                    Task { await instances.appState.runOnce() } 
                }
                .keyboardShortcut("k", modifiers: [.option, .command])
                .buttonStyle(.borderedProminent)
                
                // Translation button (only if enabled)
                if instances.appState.translationEnabled {
                    Button("Translate (⌥⌘T)") {
                        Task { await instances.appState.runTranslation() }
                    }
                    .keyboardShortcut("t", modifiers: [.option, .command])
                }
                
                // Update button (only if update available)
                if instances.updateManager.hasUpdate {
                    Button("Update Available (v\(instances.updateManager.latestVersion))") {
                        instances.updateManager.downloadAndInstallUpdate()
                    }
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
                }
                
                Divider()
                
                // Settings and Quit
                Button("Settings...") { 
                    instances.settingsManager.showSettings(instances.appState, instances.updateManager) 
                }
                
                Button("Quit Promptify") { 
                    NSApplication.shared.terminate(nil) 
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
            .padding(12)
            .onAppear {
                Task {
                    await instances.updateManager.checkForUpdates()
                }
            }
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var instances = AppInstances.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app appears in dock
        NSApplication.shared.setActivationPolicy(.regular)
        
        // Show settings window on first launch
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            DispatchQueue.main.async {
                self.instances.settingsManager.showSettings(self.instances.appState, self.instances.updateManager)
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show settings window when dock icon is clicked
        instances.settingsManager.showSettings(instances.appState, instances.updateManager)
        return false
    }
}

