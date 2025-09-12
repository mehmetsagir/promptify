import SwiftUI
import AppKit

/// Dedicated window for showing update progress
class UpdateProgressWindowManager: ObservableObject {
    private var progressWindow: NSWindow?
    
    @MainActor
    func showUpdateProgress(_ autoUpdateService: AutoUpdateService) {
        if progressWindow == nil {
            let progressView = UpdateProgressView(autoUpdateService: autoUpdateService) {
                self.closeUpdateProgress()
            }
            
            let hostingView = NSHostingView(rootView: progressView)
            
            progressWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            progressWindow?.title = "Updating Promptify"
            progressWindow?.contentView = hostingView
            progressWindow?.center()
            progressWindow?.isReleasedWhenClosed = false
            progressWindow?.level = .floating
            
            // Prevent closing during update
            progressWindow?.standardWindowButton(.closeButton)?.isEnabled = false
        }
        
        progressWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeUpdateProgress() {
        progressWindow?.close()
        progressWindow = nil
    }
}

struct UpdateProgressView: View {
    @ObservedObject var autoUpdateService: AutoUpdateService
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading) {
                    Text("Updating Promptify")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Please wait while we update your app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Progress Section
            VStack(spacing: 12) {
                // Status Text
                Text(autoUpdateService.updateStatus)
                    .font(.body)
                    .multilineTextAlignment(.center)
                
                // Progress Bar
                ProgressView(value: autoUpdateService.updateProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
                
                // Percentage
                Text("\(Int(autoUpdateService.updateProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Error State
            if autoUpdateService.hasError {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        
                        Text("Update Failed")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    
                    Text(autoUpdateService.errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Close") {
                        onClose()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top)
            }
            
            // Success Animation (when complete)
            if autoUpdateService.updateProgress >= 1.0 && !autoUpdateService.hasError {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        Text("Update Complete!")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    
                    Text("Restarting application...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: autoUpdateService.updateProgress)
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 400, height: 200)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

/// HUD-style update notification for quick updates
struct UpdateHUD {
    static func showQuickUpdate() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.level = .floating
        window.ignoresMouseEvents = true
        
        let hostingView = NSHostingView(rootView: QuickUpdateView())
        window.contentView = hostingView
        
        // Position at center of screen
        if let screen = NSScreen.main {
            let screenRect = screen.frame
            let windowRect = window.frame
            let x = screenRect.midX - windowRect.width / 2
            let y = screenRect.midY - windowRect.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.makeKeyAndOrderFront(nil)
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            window.close()
        }
    }
}

struct QuickUpdateView: View {
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Update Available")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Check Settings > Diagnostics")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                opacity = 1.0
                scale = 1.0
            }
        }
    }
}