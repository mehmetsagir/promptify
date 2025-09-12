import Foundation

/// Handles migration of user settings between app versions
struct SettingsMigrator {
    
    /// Current migration version
    private static let currentMigrationVersion = "1.1"
    
    /// Perform settings migration if needed
    static func migrateIfNeeded() {
        let lastMigrationVersion = UserDefaults.standard.string(forKey: "settingsMigrationVersion")
        
        guard lastMigrationVersion != currentMigrationVersion else {
            print("✅ Settings migration not needed")
            return
        }
        
        print("🔄 Starting settings migration from \(lastMigrationVersion ?? "none") to \(currentMigrationVersion)")
        
        performMigrations(from: lastMigrationVersion)
        
        // Mark migration as completed
        UserDefaults.standard.set(currentMigrationVersion, forKey: "settingsMigrationVersion")
        UserDefaults.standard.synchronize()
        
        print("✅ Settings migration completed")
    }
    
    /// Restore settings from backup if available
    static func restoreFromBackupIfNeeded() {
        guard let backup = UserDefaults.standard.dictionary(forKey: "settingsBackup"),
              let backupDate = UserDefaults.standard.object(forKey: "settingsBackupDate") as? Date else {
            print("📦 No settings backup found")
            return
        }
        
        // Only restore if backup is recent (within last 7 days)
        let daysSinceBackup = Date().timeIntervalSince(backupDate) / (24 * 60 * 60)
        guard daysSinceBackup <= 7 else {
            print("⏰ Settings backup too old, skipping restore")
            return
        }
        
        print("📦 Restoring settings from backup...")
        
        // Restore critical user settings
        let criticalSettings = [
            "customHotkeyKey",
            "customHotkeyModifiers", 
            "selectedModel",
            "autoTranslate",
            "sourceLanguage",
            "targetLanguage",
            "enableAudioFeedback",
            "useClipboardFallback"
        ]
        
        for key in criticalSettings {
            if let value = backup[key] {
                UserDefaults.standard.set(value, forKey: key)
                print("📦 Restored \(key)")
            }
        }
        
        UserDefaults.standard.synchronize()
        print("✅ Settings restore completed")
    }
    
    /// Create backup of current settings
    static func createBackup() {
        let settingsToBackup = [
            "customHotkeyKey",
            "customHotkeyModifiers",
            "selectedModel", 
            "autoTranslate",
            "launchAtLogin",
            "useClipboardFallback",
            "enableAudioFeedback",
            "hideFromDock",
            "translationEnabled",
            "sourceLanguage",
            "targetLanguage",
            "translationHotkeyKey",
            "translationHotkeyModifiers",
            "voiceEnhancementHotkeyKey",
            "voiceEnhancementHotkeyModifiers",
            "voiceTranslationHotkeyKey", 
            "voiceTranslationHotkeyModifiers",
            "speechToTextToggleEnabled",
            "speechToTextToggleKey"
        ]
        
        var backup: [String: Any] = [:]
        for key in settingsToBackup {
            if let value = UserDefaults.standard.object(forKey: key) {
                backup[key] = value
            }
        }
        
        UserDefaults.standard.set(backup, forKey: "settingsBackup")
        UserDefaults.standard.set(Date(), forKey: "settingsBackupDate")
        UserDefaults.standard.synchronize()
        
        print("💾 Settings backup created with \(backup.count) items")
    }
    
    // MARK: - Migration Logic
    
    private static func performMigrations(from version: String?) {
        // Migration from no version (initial install or very old version)
        if version == nil {
            migrateFromNoVersion()
        }
        
        // Migration from version 1.0 to 1.1
        if version == nil || version == "1.0" {
            migrateFrom1_0To1_1()
        }
        
        // Add future migrations here as needed
    }
    
    private static func migrateFromNoVersion() {
        print("🔄 Migrating from no version...")
        
        // Set up default values for new installations
        let defaults: [String: Any] = [
            "autoTranslate": true,
            "launchAtLogin": false, // Changed default for better UX
            "selectedModel": "gpt-3.5-turbo",
            "useClipboardFallback": true,
            "enableAudioFeedback": true,
            "hideFromDock": false,
            "translationEnabled": false,
            "sourceLanguage": "English", // Changed to English as default for wider audience
            "targetLanguage": "Turkish",
            "speechToTextToggleEnabled": false
        ]
        
        for (key, value) in defaults {
            if UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(value, forKey: key)
                print("🔄 Set default \(key) = \(value)")
            }
        }
    }
    
    private static func migrateFrom1_0To1_1() {
        print("🔄 Migrating from 1.0 to 1.1...")
        
        // Example: Convert old hotkey format to new format
        if let oldHotkey = UserDefaults.standard.string(forKey: "globalHotkey") {
            // Convert old format to new format
            UserDefaults.standard.set(oldHotkey, forKey: "customHotkeyKey")
            UserDefaults.standard.removeObject(forKey: "globalHotkey")
            print("🔄 Migrated hotkey format")
        }
        
        // Fix default language order for international users
        let currentSource = UserDefaults.standard.string(forKey: "sourceLanguage") ?? ""
        let currentTarget = UserDefaults.standard.string(forKey: "targetLanguage") ?? ""
        
        // If both are set to Turkish/English, swap them for better international UX
        if currentSource == "Turkish" && currentTarget == "English" {
            UserDefaults.standard.set("English", forKey: "sourceLanguage")
            UserDefaults.standard.set("Turkish", forKey: "targetLanguage")
            print("🔄 Updated language defaults for international users")
        }
        
        // Enable translation by default for new users if not explicitly set
        if UserDefaults.standard.object(forKey: "translationEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "translationEnabled")
            print("🔄 Enabled translation by default")
        }
    }
    
    /// Clean up old/deprecated settings
    static func cleanupDeprecatedSettings() {
        let deprecatedKeys = [
            "globalHotkey", // Old hotkey format
            "oldPermissionCheck", // Old permission tracking
            "legacyTranslationMode", // Old translation system
            "tempCachedValues", // Temporary cache values
            "debugModeEnabled" // Debug flags that shouldn't persist
        ]
        
        for key in deprecatedKeys {
            if UserDefaults.standard.object(forKey: key) != nil {
                UserDefaults.standard.removeObject(forKey: key)
                print("🧹 Removed deprecated setting: \(key)")
            }
        }
        
        UserDefaults.standard.synchronize()
    }
    
    /// Validate current settings and fix any inconsistencies
    static func validateAndFixSettings() {
        print("🔍 Validating settings...")
        
        // Ensure model is valid
        let validModels = ["gpt-3.5-turbo", "gpt-4", "gpt-4-turbo"]
        let currentModel = UserDefaults.standard.string(forKey: "selectedModel") ?? ""
        if !validModels.contains(currentModel) {
            UserDefaults.standard.set("gpt-3.5-turbo", forKey: "selectedModel")
            print("🔧 Fixed invalid model selection")
        }
        
        // Ensure languages are valid
        let validLanguages = ["English", "Turkish", "Spanish", "French", "German", "Italian"]
        let sourceLanguage = UserDefaults.standard.string(forKey: "sourceLanguage") ?? ""
        let targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? ""
        
        if !validLanguages.contains(sourceLanguage) {
            UserDefaults.standard.set("English", forKey: "sourceLanguage")
            print("🔧 Fixed invalid source language")
        }
        
        if !validLanguages.contains(targetLanguage) {
            UserDefaults.standard.set("Turkish", forKey: "targetLanguage")
            print("🔧 Fixed invalid target language")
        }
        
        // Ensure source and target languages are different
        if sourceLanguage == targetLanguage && !sourceLanguage.isEmpty {
            UserDefaults.standard.set("English", forKey: "sourceLanguage")
            UserDefaults.standard.set("Turkish", forKey: "targetLanguage")
            print("🔧 Fixed identical source and target languages")
        }
        
        UserDefaults.standard.synchronize()
        print("✅ Settings validation completed")
    }
}