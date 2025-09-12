import Foundation
import AppKit

/// Enhanced update manager with cleanup and migration capabilities
@MainActor
class UpdateManager: ObservableObject {
    @Published var hasUpdate = false
    @Published var latestVersion = ""
    @Published var isCheckingForUpdates = false
    @Published var isDownloadingUpdate = false
    @Published var downloadProgress: Double = 0.0
    
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let githubAPI = "https://api.github.com/repos/mehmetsagir/Promptify/releases/latest"
    
    /// Check for updates and perform cleanup if needed
    func checkForUpdates(performCleanup: Bool = true) async {
        isCheckingForUpdates = true
        
        // Perform permission diagnostic and cleanup if this is a new version
        if performCleanup && PermissionDiagnostic.shouldResetPermissions() {
            print("🧹 Performing permission cleanup for new version...")
            PermissionDiagnostic.resetPermissionState()
            await migrateUserSettings()
        }
        
        guard let url = URL(string: githubAPI) else {
            isCheckingForUpdates = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tagName = json["tag_name"] as? String {
                
                let latestVersionNumber = tagName.replacingOccurrences(of: "v", with: "")
                
                self.latestVersion = latestVersionNumber
                self.hasUpdate = self.isNewerVersion(latest: latestVersionNumber, current: currentVersion)
                
                if self.hasUpdate {
                    print("🔄 Update available: \(currentVersion) → \(latestVersionNumber)")
                }
            }
        } catch {
            print("❌ Error checking for updates: \(error)")
        }
        
        isCheckingForUpdates = false
    }
    
    /// Download and install update with automatic cleanup
    func downloadAndInstallUpdate() async {
        guard hasUpdate else { return }
        
        isDownloadingUpdate = true
        downloadProgress = 0.0
        
        do {
            // Get download URL from latest release
            let downloadURL = try await getDownloadURL()
            
            // Download the update
            let localURL = try await downloadUpdate(from: downloadURL)
            
            // Pre-installation cleanup
            await performPreInstallationCleanup()
            
            // Install the update
            installUpdate(from: localURL)
            
        } catch {
            print("❌ Error downloading update: \(error)")
            showUpdateError(error)
        }
        
        isDownloadingUpdate = false
    }
    
    /// Open browser to latest release page (fallback method)
    func openLatestRelease() {
        guard let url = URL(string: "https://github.com/mehmetsagir/Promptify/releases/latest") else {
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Private Methods
    
    private func getDownloadURL() async throws -> URL {
        guard let url = URL(string: githubAPI) else {
            throw UpdateError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assets = json["assets"] as? [[String: Any]] else {
            throw UpdateError.invalidResponse
        }
        
        // Look for .dmg file in assets
        for asset in assets {
            if let name = asset["name"] as? String,
               let downloadURLString = asset["browser_download_url"] as? String,
               name.hasSuffix(".dmg"),
               let downloadURL = URL(string: downloadURLString) {
                return downloadURL
            }
        }
        
        throw UpdateError.noDownloadFound
    }
    
    private func downloadUpdate(from url: URL) async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let localURL = documentsPath.appendingPathComponent("Promptify-Update.dmg")
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: localURL)
        
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        try FileManager.default.moveItem(at: tempURL, to: localURL)
        
        downloadProgress = 1.0
        return localURL
    }
    
    private func performPreInstallationCleanup() async {
        print("🧹 Performing pre-installation cleanup...")
        
        // Reset permission states to force fresh checks
        PermissionDiagnostic.resetPermissionState()
        
        // Clear any temporary caches
        clearTemporaryCaches()
        
        // Backup user settings
        backupUserSettings()
        
        print("✅ Pre-installation cleanup completed")
    }
    
    private func installUpdate(from localURL: URL) {
        // Open the downloaded DMG
        NSWorkspace.shared.open(localURL)
        
        // Show installation instructions
        let alert = NSAlert()
        alert.messageText = "Update Downloaded"
        alert.informativeText = "The update has been downloaded and opened. Please:\n\n1. Drag the new Promptify to Applications folder\n2. Replace the existing app when prompted\n3. Restart Promptify\n\nYour settings will be preserved."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func migrateUserSettings() async {
        print("🔄 Migrating user settings...")
        
        let migrationVersion = UserDefaults.standard.string(forKey: "settingsMigrationVersion")
        let currentMigrationVersion = "1.0"
        
        if migrationVersion != currentMigrationVersion {
            // Perform any necessary setting migrations here
            
            // Example: Migrate old hotkey format to new format
            if let oldHotkey = UserDefaults.standard.string(forKey: "oldHotkeyKey") {
                UserDefaults.standard.set(oldHotkey, forKey: "customHotkeyKey")
                UserDefaults.standard.removeObject(forKey: "oldHotkeyKey")
            }
            
            // Mark migration as completed
            UserDefaults.standard.set(currentMigrationVersion, forKey: "settingsMigrationVersion")
            
            print("✅ Settings migration completed")
        }
    }
    
    private func clearTemporaryCaches() {
        // Clear app-specific temporary files
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("com.mehmetsagir.promptify")
        try? FileManager.default.removeItem(at: tempDir)
        
        // Clear any cached permission states that might be stale
        let keysToRemove = [
            "cachedAccessibilityCheck",
            "cachedInputMonitoringCheck",
            "cachedMicrophoneCheck"
        ]
        
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    private func backupUserSettings() {
        let settingsToBackup = [
            "customHotkeyKey",
            "customHotkeyModifiers",
            "selectedModel",
            "autoTranslate",
            "useClipboardFallback",
            "enableAudioFeedback",
            "sourceLanguage",
            "targetLanguage"
        ]
        
        var backup: [String: Any] = [:]
        for key in settingsToBackup {
            if let value = UserDefaults.standard.object(forKey: key) {
                backup[key] = value
            }
        }
        
        UserDefaults.standard.set(backup, forKey: "settingsBackup")
        UserDefaults.standard.set(Date(), forKey: "settingsBackupDate")
        
        print("💾 User settings backed up")
    }
    
    private func showUpdateError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Update Failed"
        alert.informativeText = "Failed to download the update automatically. You can download it manually from GitHub.\n\nError: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open GitHub")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            openLatestRelease()
        }
    }
    
    private func isNewerVersion(latest: String, current: String) -> Bool {
        let latestComponents = latest.components(separatedBy: ".").compactMap { Int($0) }
        let currentComponents = current.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxLength = max(latestComponents.count, currentComponents.count)
        
        for i in 0..<maxLength {
            let latestPart = i < latestComponents.count ? latestComponents[i] : 0
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0
            
            if latestPart > currentPart {
                return true
            } else if latestPart < currentPart {
                return false
            }
        }
        
        return false
    }
}

// MARK: - Update Errors

enum UpdateError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noDownloadFound
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid update URL"
        case .invalidResponse:
            return "Invalid response from update server"
        case .noDownloadFound:
            return "No download file found in release"
        case .downloadFailed:
            return "Failed to download update file"
        }
    }
}