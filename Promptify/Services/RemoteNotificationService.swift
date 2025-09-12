import Foundation

/// Server-side push notification system for instant update alerts
class RemoteNotificationService: ObservableObject {
    static let shared = RemoteNotificationService()
    
    private let webhookURL = "https://api.github.com/repos/mehmetsagir/promptify/releases/latest"
    private var pollTimer: Timer?
    private var lastKnownVersion: String?
    
    private init() {
        loadLastKnownVersion()
    }
    
    /// Start monitoring for new releases
    func startMonitoring() {
        print("🔔 Starting remote notification monitoring...")
        
        // Poll GitHub API every 30 minutes
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in
            Task {
                await self.checkForNewRelease()
            }
        }
        
        // Initial check
        Task {
            await checkForNewRelease()
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        print("🔔 Remote notification monitoring stopped")
    }
    
    private func checkForNewRelease() async {
        do {
            guard let url = URL(string: webhookURL) else { return }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                return
            }
            
            let version = tagName.replacingOccurrences(of: "v", with: "")
            
            // Check if this is a new version
            if let lastVersion = lastKnownVersion,
               version != lastVersion,
               isNewerVersion(latest: version, current: lastVersion) {
                
                print("🔔 New release detected: \(version)")
                
                // Send local notification
                await MainActor.run {
                    NotificationService.shared.showUpdateAvailable(version: version)
                }
                
                // Update last known version
                lastKnownVersion = version
                saveLastKnownVersion(version)
            }
            
        } catch {
            print("❌ Failed to check for new release: \(error)")
        }
    }
    
    private func loadLastKnownVersion() {
        lastKnownVersion = UserDefaults.standard.string(forKey: "lastKnownReleaseVersion")
        
        // If no last known version, use current app version
        if lastKnownVersion == nil {
            lastKnownVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        }
    }
    
    private func saveLastKnownVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: "lastKnownReleaseVersion")
        UserDefaults.standard.synchronize()
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

// MARK: - Webhook Integration (Optional Advanced Feature)

/// GitHub webhook integration for instant notifications
struct WebhookNotificationService {
    
    /// Setup GitHub webhook for instant notifications
    /// This would require a server endpoint to receive webhook and push notifications
    static func setupGitHubWebhook() {
        print("🔗 GitHub Webhook setup would go here...")
        print("📋 Steps:")
        print("   1. Create server endpoint (e.g., Vercel, Netlify Functions)")
        print("   2. Setup GitHub webhook for 'release' events")
        print("   3. Server sends push notifications to app instances")
        print("   4. Use Apple Push Notification Service (APNs)")
    }
}

// MARK: - Push Notification Payload Example

/*
Server-side webhook endpoint pseudocode:

```javascript
// Vercel function: api/github-webhook.js
export default async function handler(req, res) {
    if (req.method === 'POST') {
        const { action, release } = req.body;
        
        if (action === 'published') {
            const version = release.tag_name.replace('v', '');
            
            // Send push notification to all app instances
            await sendPushNotification({
                title: 'Promptify Update Available',
                body: `Version ${version} is ready to install`,
                version: version,
                downloadUrl: release.assets[0].browser_download_url
            });
        }
    }
    
    res.status(200).json({ success: true });
}
```

GitHub Webhook Settings:
- URL: https://your-domain.vercel.app/api/github-webhook
- Content type: application/json  
- Events: Releases
*/