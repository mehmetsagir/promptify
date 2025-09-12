import Foundation
import UserNotifications
import AppKit

/// Native macOS notification service for update alerts
@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    private override init() {
        super.init()
        setupNotifications()
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
    }
    
    /// Request notification permission
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("❌ Notification permission denied: \(error?.localizedDescription ?? "Unknown")")
                }
            }
        }
    }
    
    /// Show update available notification
    func showUpdateAvailable(version: String) {
        let content = UNMutableNotificationContent()
        content.title = "Promptify Update Available"
        content.body = "Version \(version) is ready to install. Tap to update automatically."
        content.sound = .default
        content.categoryIdentifier = "UPDATE_CATEGORY"
        
        // Custom data for handling
        content.userInfo = [
            "type": "update_available",
            "version": version,
            "action": "install_update"
        ]
        
        let request = UNNotificationRequest(
            identifier: "update_available_\(version)",
            content: content,
            trigger: nil // Show immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to show notification: \(error)")
            } else {
                print("✅ Update notification shown for version \(version)")
            }
        }
    }
    
    /// Show update installation complete notification
    func showUpdateComplete(version: String) {
        let content = UNMutableNotificationContent()
        content.title = "Promptify Updated"
        content.body = "Successfully updated to version \(version). Enjoy the new features!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "update_complete_\(version)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to show completion notification: \(error)")
            } else {
                print("✅ Update completion notification shown")
            }
        }
    }
    
    /// Show permission reminder notification
    func showPermissionReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Promptify Needs Permissions"
        content.body = "Grant accessibility permissions to unlock all features. Tap to open settings."
        content.sound = .default
        content.categoryIdentifier = "PERMISSION_CATEGORY"
        
        content.userInfo = [
            "type": "permission_reminder",
            "action": "open_settings"
        ]
        
        let request = UNNotificationRequest(
            identifier: "permission_reminder",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to show permission notification: \(error)")
            } else {
                print("✅ Permission reminder notification shown")
            }
        }
    }
    
    /// Schedule periodic update checks (when app is not running)
    func scheduleUpdateCheck() {
        let content = UNMutableNotificationContent()
        content.title = "Checking for Updates"
        content.body = "Promptify is checking for new updates..."
        content.sound = nil // Silent
        
        // Check every 24 hours
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 86400, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "scheduled_update_check",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule update check: \(error)")
            } else {
                print("✅ Scheduled update check notification")
            }
        }
    }
    
    /// Clear all notifications
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🧹 All notifications cleared")
    }
}

// MARK: - Notification Delegate
extension NotificationService: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is active
        completionHandler([.alert, .sound])
    }
    
    /// Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        let type = userInfo["type"] as? String ?? ""
        
        switch type {
        case "update_available":
            handleUpdateNotificationTap(userInfo: userInfo)
            
        case "permission_reminder":
            handlePermissionNotificationTap()
            
        default:
            print("🔔 Unknown notification type: \(type)")
        }
        
        completionHandler()
    }
    
    private func handleUpdateNotificationTap(userInfo: [AnyHashable: Any]) {
        print("🔔 Update notification tapped")
        
        // Show update progress and start automatic update
        let instances = AppInstances.shared
        
        Task {
            // Check for updates first
            await instances.updateManager.checkForUpdates(performCleanup: true)
            
            if instances.updateManager.hasUpdate {
                // Create and show auto-update service
                let autoUpdateService = AutoUpdateService(updateManager: instances.updateManager)
                let progressWindow = UpdateProgressWindowManager()
                
                // Show progress window
                progressWindow.showUpdateProgress(autoUpdateService)
                
                // Start automatic update
                await autoUpdateService.performAutomaticUpdate()
            }
        }
    }
    
    private func handlePermissionNotificationTap() {
        print("🔔 Permission notification tapped")
        
        // Open settings window
        let instances = AppInstances.shared
        instances.settingsManager.showSettings(instances.appState, instances.updateManager)
    }
}