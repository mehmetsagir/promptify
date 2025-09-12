import Foundation

/// Helper for testing the update system during development
#if DEBUG
struct UpdateTestHelper {
    
    /// Simulate update availability for testing
    @MainActor
    static func simulateUpdateAvailable() {
        print("🧪 Simulating update available...")
        
        // Mock the update manager to show update available
        let updateManager = UpdateManager()
        Task { @MainActor in
            updateManager.hasUpdate = true
            updateManager.latestVersion = "99.99.99"
        }
    }
    
    /// Test the permission diagnostic system
    static func testPermissionDiagnostic() {
        print("🧪 Testing permission diagnostic...")
        
        let state = PermissionDiagnostic.performDiagnostic()
        print("🔍 Diagnostic result: \(state)")
        
        // Test reset
        PermissionDiagnostic.resetPermissionState()
        print("🧹 Permission state reset completed")
    }
    
    /// Test settings migration
    static func testSettingsMigration() {
        print("🧪 Testing settings migration...")
        
        // Create a backup first
        SettingsMigrator.createBackup()
        print("💾 Backup created")
        
        // Test migration
        SettingsMigrator.migrateIfNeeded()
        print("🔄 Migration tested")
        
        // Test cleanup
        SettingsMigrator.cleanupDeprecatedSettings()
        print("🧹 Cleanup tested")
        
        // Test validation
        SettingsMigrator.validateAndFixSettings()
        print("🔧 Validation tested")
    }
    
    /// Create a mock DMG for testing (creates empty file)
    static func createMockDMG() -> URL? {
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let mockDMGURL = downloadsPath.appendingPathComponent("PromptifyTest.dmg")
        
        // Create empty file for testing
        FileManager.default.createFile(atPath: mockDMGURL.path, contents: Data(), attributes: nil)
        
        print("🧪 Created mock DMG at: \(mockDMGURL.path)")
        return mockDMGURL
    }
    
    /// Test update flow with safe mock operations
    @MainActor
    static func testUpdateFlowSafe() {
        print("🧪 Testing update flow (safe mode)...")
        
        let autoUpdateService = AutoUpdateService(updateManager: UpdateManager())
        
        Task { @MainActor in
            // Test status updates without actual operations
            autoUpdateService.updateStatus = "Testing download..."
            autoUpdateService.updateProgress = 0.3
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            autoUpdateService.updateStatus = "Testing installation..."
            autoUpdateService.updateProgress = 0.7
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            autoUpdateService.updateStatus = "Testing complete"
            autoUpdateService.updateProgress = 1.0
            
            print("✅ Safe update flow test completed")
        }
    }
    
    /// Log current system information for debugging
    static func logSystemInfo() {
        print("🔍 System Information:")
        print("  macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("  Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("  Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
        print("  Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")")
        print("  App Path: \(Bundle.main.bundlePath)")
        
        // Check permissions
        let hasAccessibility = Permission.hasAccessibility
        let hasInputMonitoring = Permission.hasInputMonitoring()
        let hasMicrophone = Permission.hasMicrophone
        
        print("  Permissions:")
        print("    Accessibility: \(hasAccessibility)")
        print("    Input Monitoring: \(hasInputMonitoring)")
        print("    Microphone: \(hasMicrophone)")
    }
}
#endif