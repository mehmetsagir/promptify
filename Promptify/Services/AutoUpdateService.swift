import Foundation
import AppKit

/// Fully automatic update service that handles the entire update process
@MainActor
class AutoUpdateService: ObservableObject {
    @Published var isUpdating = false
    @Published var updateProgress: Double = 0.0
    @Published var updateStatus = "Checking for updates..."
    @Published var hasError = false
    @Published var errorMessage = ""
    
    private let updateManager: UpdateManager
    
    init(updateManager: UpdateManager) {
        self.updateManager = updateManager
    }
    
    /// Perform complete automatic update
    func performAutomaticUpdate() async {
        isUpdating = true
        hasError = false
        updateProgress = 0.0
        
        do {
            // Step 1: Check for updates
            updateStatus = "Checking for updates..."
            updateProgress = 0.1
            
            await updateManager.checkForUpdates(performCleanup: false)
            
            guard updateManager.hasUpdate else {
                updateStatus = "No updates available"
                isUpdating = false
                return
            }
            
            // Step 2: Download the update
            updateStatus = "Downloading update..."
            updateProgress = 0.2
            
            let downloadURL = try await getDownloadURL()
            let localDMG = try await downloadUpdate(from: downloadURL)
            
            updateProgress = 0.6
            
            // Step 3: Prepare for installation
            updateStatus = "Preparing installation..."
            await performPreInstallationCleanup()
            
            updateProgress = 0.7
            
            // Step 4: Install the update
            updateStatus = "Installing update..."
            try await installUpdateAutomatically(from: localDMG)
            
            updateProgress = 0.9
            
            // Step 5: Restart the application
            updateStatus = "Restarting application..."
            updateProgress = 1.0
            
            await restartApplication()
            
        } catch {
            hasError = true
            errorMessage = error.localizedDescription
            updateStatus = "Update failed"
            print("❌ Auto-update failed: \(error)")
        }
        
        isUpdating = false
    }
    
    // MARK: - Private Implementation
    
    private func getDownloadURL() async throws -> URL {
        let githubAPI = "https://api.github.com/repos/mehmetsagir/Promptify/releases/latest"
        
        guard let url = URL(string: githubAPI) else {
            throw AutoUpdateError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assets = json["assets"] as? [[String: Any]] else {
            throw AutoUpdateError.invalidResponse
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
        
        throw AutoUpdateError.noDownloadFound
    }
    
    private func downloadUpdate(from url: URL) async throws -> URL {
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let localURL = downloadsPath.appendingPathComponent("PromptifyUpdate-\(UUID().uuidString).dmg")
        
        // Custom URLSession with progress tracking
        let session = URLSession.shared
        let (tempURL, response) = try await session.download(from: url)
        
        // Verify download
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AutoUpdateError.downloadFailed
        }
        
        // Move to final location
        try FileManager.default.moveItem(at: tempURL, to: localURL)
        
        print("✅ Downloaded update to: \(localURL.path)")
        return localURL
    }
    
    private func performPreInstallationCleanup() async {
        print("🧹 Performing pre-installation cleanup...")
        
        // Backup current settings
        SettingsMigrator.createBackup()
        
        // Reset permission states to force fresh checks after update
        PermissionDiagnostic.resetPermissionState()
        
        // Clean temporary files
        clearTemporaryFiles()
        
        print("✅ Pre-installation cleanup completed")
    }
    
    private func installUpdateAutomatically(from dmgPath: URL) async throws {
        print("🔧 Starting automatic installation from: \(dmgPath.path)")
        
        // Step 1: Mount the DMG
        let mountPoint = try await mountDMG(dmgPath)
        defer {
            // Always unmount when done
            Task {
                await unmountDMG(mountPoint)
            }
        }
        
        // Step 2: Find the app in the mounted DMG
        let sourceApp = try findAppInDMG(mountPoint)
        
        // Step 3: Get current app path
        let currentAppPath = Bundle.main.bundlePath
        let currentAppURL = URL(fileURLWithPath: currentAppPath)
        
        // Step 4: Create backup of current app
        let backupPath = try createAppBackup(currentAppURL)
        
        do {
            // Step 5: Replace the current app
            try await replaceApplication(source: sourceApp, destination: currentAppURL)
            
            print("✅ Application successfully updated")
            
            // Clean up backup after successful installation
            try? FileManager.default.removeItem(at: backupPath)
            
        } catch {
            // If replacement fails, restore from backup
            print("❌ App replacement failed, restoring backup...")
            try? FileManager.default.removeItem(at: currentAppURL)
            try? FileManager.default.moveItem(at: backupPath, to: currentAppURL)
            throw error
        }
    }
    
    private func mountDMG(_ dmgPath: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            task.arguments = ["attach", dmgPath.path, "-nobrowse", "-quiet"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            task.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    // Parse mount point from output
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        if line.contains("/Volumes/") {
                            let components = line.components(separatedBy: .whitespaces)
                            if let mountPoint = components.last, !mountPoint.isEmpty {
                                let mountURL = URL(fileURLWithPath: mountPoint)
                                print("✅ DMG mounted at: \(mountPoint)")
                                continuation.resume(returning: mountURL)
                                return
                            }
                        }
                    }
                    continuation.resume(throwing: AutoUpdateError.mountFailed("Could not parse mount point"))
                } else {
                    print("❌ DMG mount failed: \(output)")
                    continuation.resume(throwing: AutoUpdateError.mountFailed(output))
                }
            }
            
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func unmountDMG(_ mountPoint: URL) async {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        task.arguments = ["detach", mountPoint.path, "-quiet"]
        
        do {
            try task.run()
            task.waitUntilExit()
            print("✅ DMG unmounted: \(mountPoint.path)")
        } catch {
            print("⚠️ Failed to unmount DMG: \(error)")
        }
    }
    
    private func findAppInDMG(_ mountPoint: URL) throws -> URL {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
        
        for item in contents {
            if item.pathExtension == "app" && item.lastPathComponent.contains("Promptify") {
                print("✅ Found app in DMG: \(item.path)")
                return item
            }
        }
        
        throw AutoUpdateError.appNotFoundInDMG
    }
    
    private func createAppBackup(_ appURL: URL) throws -> URL {
        let backupURL = appURL.appendingPathExtension("backup")
        
        // Remove existing backup if present
        try? FileManager.default.removeItem(at: backupURL)
        
        // Create new backup
        try FileManager.default.copyItem(at: appURL, to: backupURL)
        
        print("✅ Created app backup: \(backupURL.path)")
        return backupURL
    }
    
    private func replaceApplication(source: URL, destination: URL) async throws {
        let fileManager = FileManager.default
        
        // Remove current app
        try fileManager.removeItem(at: destination)
        
        // Copy new app
        try fileManager.copyItem(at: source, to: destination)
        
        // Fix permissions
        try await fixApplicationPermissions(destination)
        
        print("✅ Application replaced successfully")
    }
    
    private func fixApplicationPermissions(_ appURL: URL) async throws {
        // Make the app executable
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/chmod")
        task.arguments = ["-R", "755", appURL.path]
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            throw AutoUpdateError.permissionsFailed
        }
        
        print("✅ Application permissions fixed")
    }
    
    private func restartApplication() async {
        print("🔄 Restarting application...")
        
        // Show restart notification to user
        let alert = NSAlert()
        alert.messageText = "Update Complete"
        alert.informativeText = "Promptify has been successfully updated. The application will now restart to complete the installation."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Restart Now")
        
        // Run alert on main thread
        await MainActor.run {
            alert.runModal()
        }
        
        // Get current app path
        let appPath = Bundle.main.bundlePath
        
        // Create restart script
        let restartScript = """
        #!/bin/bash
        sleep 2
        open "\(appPath)"
        """
        
        // Write script to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("restart_promptify.sh")
        
        do {
            try restartScript.write(to: scriptURL, atomically: true, encoding: .utf8)
            
            // Make script executable
            let chmodTask = Process()
            chmodTask.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodTask.arguments = ["+x", scriptURL.path]
            try chmodTask.run()
            chmodTask.waitUntilExit()
            
            // Execute restart script
            let restartTask = Process()
            restartTask.executableURL = scriptURL
            try restartTask.run()
            
            // Exit current app
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
            
        } catch {
            print("❌ Failed to restart app: \(error)")
            // Fallback: just quit the app
            NSApp.terminate(nil)
        }
    }
    
    private func clearTemporaryFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        let promptifyTemp = tempDir.appendingPathComponent("com.mehmetsagir.promptify")
        
        try? FileManager.default.removeItem(at: promptifyTemp)
        print("🧹 Cleared temporary files")
    }
}

// MARK: - Auto Update Errors

enum AutoUpdateError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noDownloadFound
    case downloadFailed
    case mountFailed(String)
    case appNotFoundInDMG
    case permissionsFailed
    case installationFailed(String)
    
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
        case .mountFailed(let details):
            return "Failed to mount DMG: \(details)"
        case .appNotFoundInDMG:
            return "Application not found in downloaded DMG"
        case .permissionsFailed:
            return "Failed to set application permissions"
        case .installationFailed(let details):
            return "Installation failed: \(details)"
        }
    }
}