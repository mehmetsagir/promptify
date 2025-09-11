import Foundation
import AppKit

class UpdateManager: ObservableObject {
    @Published var hasUpdate = false
    @Published var latestVersion = ""
    @Published var isCheckingForUpdates = false
    
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let githubAPI = "https://api.github.com/repos/mehmetsagir/Promptify/releases/latest"
    
    func checkForUpdates() async {
        await MainActor.run {
            isCheckingForUpdates = true
        }
        
        guard let url = URL(string: githubAPI) else {
            await MainActor.run {
                isCheckingForUpdates = false
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tagName = json["tag_name"] as? String {
                
                let latestVersionNumber = tagName.replacingOccurrences(of: "v", with: "")
                
                await MainActor.run {
                    self.latestVersion = latestVersionNumber
                    self.hasUpdate = self.isNewerVersion(latest: latestVersionNumber, current: currentVersion)
                    self.isCheckingForUpdates = false
                }
            }
        } catch {
            print("Error checking for updates: \(error)")
            await MainActor.run {
                isCheckingForUpdates = false
            }
        }
    }
    
    func downloadAndInstallUpdate() {
        guard let url = URL(string: "https://github.com/mehmetsagir/Promptify/releases/latest") else {
            return
        }
        
        NSWorkspace.shared.open(url)
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