import Foundation
import AVFoundation
import ApplicationServices

/// Diagnostic tool for permission state analysis and reset
struct PermissionDiagnostic {
    
    /// Comprehensive permission state check
    static func performDiagnostic() -> PermissionState {
        let accessibility = checkAccessibilityPermission()
        let inputMonitoring = checkInputMonitoringPermission()
        let microphone = checkMicrophonePermission()
        
        let systemState = PermissionState(
            accessibility: accessibility.system,
            inputMonitoring: inputMonitoring.system,
            microphone: microphone.system
        )
        
        let appState = PermissionState(
            accessibility: accessibility.cached,
            inputMonitoring: inputMonitoring.cached,
            microphone: microphone.cached
        )
        
        let hasDesync = systemState != appState
        
        print("🔍 Permission Diagnostic Results:")
        print("System State: \(systemState)")
        print("App Cached State: \(appState)")
        print("Has Desync: \(hasDesync)")
        
        return systemState
    }
    
    /// Reset all permission-related caches and UserDefaults
    static func resetPermissionState() {
        print("🧹 Resetting permission state...")
        
        // Clear permission-related UserDefaults
        let keys = [
            "hasAccessibility",
            "hasInputMonitoring", 
            "hasMicrophone",
            "permissionLastChecked",
            "permissionDeniedCount"
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Force UserDefaults sync
        UserDefaults.standard.synchronize()
        
        print("✅ Permission state reset completed")
    }
    
    /// Check if permission reset is needed based on version
    static func shouldResetPermissions() -> Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let lastResetVersion = UserDefaults.standard.string(forKey: "lastPermissionResetVersion")
        
        // Reset if version changed or never reset before
        let shouldReset = lastResetVersion != currentVersion
        
        if shouldReset {
            print("🔄 Permission reset needed: \(lastResetVersion ?? "never") → \(currentVersion)")
            UserDefaults.standard.set(currentVersion, forKey: "lastPermissionResetVersion")
        }
        
        return shouldReset
    }
    
    private static func checkAccessibilityPermission() -> (system: Bool, cached: Bool) {
        let systemGranted = AXIsProcessTrusted()
        let cachedGranted = UserDefaults.standard.object(forKey: "hasAccessibility") as? Bool
        
        return (system: systemGranted, cached: cachedGranted ?? false)
    }
    
    private static func checkInputMonitoringPermission() -> (system: Bool, cached: Bool) {
        // Input monitoring is harder to check directly, use indirect method
        let systemGranted = Permission.hasInputMonitoring()
        let cachedGranted = UserDefaults.standard.object(forKey: "hasInputMonitoring") as? Bool
        
        return (system: systemGranted, cached: cachedGranted ?? false)
    }
    
    private static func checkMicrophonePermission() -> (system: Bool, cached: Bool) {
        let systemStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let systemGranted = systemStatus == .authorized
        let cachedGranted = UserDefaults.standard.object(forKey: "hasMicrophone") as? Bool
        
        return (system: systemGranted, cached: cachedGranted ?? false)
    }
}

/// Permission state representation
struct PermissionState: Equatable {
    let accessibility: Bool
    let inputMonitoring: Bool
    let microphone: Bool
    
    static func == (lhs: PermissionState, rhs: PermissionState) -> Bool {
        return lhs.accessibility == rhs.accessibility &&
               lhs.inputMonitoring == rhs.inputMonitoring &&
               lhs.microphone == rhs.microphone
    }
}

extension PermissionState: CustomStringConvertible {
    var description: String {
        return "Accessibility: \(accessibility), InputMonitoring: \(inputMonitoring), Microphone: \(microphone)"
    }
}