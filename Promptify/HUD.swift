import AppKit
import SwiftUI

// Basit HUD: hem ilerleme mesajı hem de sonuç metni gösterebiliyor.
final class HUD {
    private static var panel: NSPanel?
    private static var hosting: NSHostingView<HUDView>?

    // ---- Progress/Haberleşme
    static func show(_ text: String) {
        ensurePanelIfNeeded()
        updateProgress(text)
        panel?.makeKeyAndOrderFront(nil)
    }

    static func update(_ text: String) { updateProgress(text) }
    
    static func showSuccess(_ text: String) {
        ensurePanelIfNeeded()
        
        // Aynı progress bar'da success göster
        hosting?.rootView = HUDView(mode: .success(text: text), onCopy: nil, onClose: nil)
        hosting?.needsLayout = true
        panel?.title = ""
        
        // Text uzunluğuna göre dinamik genişlik (cömert padding)
        let textWidth = text.size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium)]).width
        let dynamicWidth = max(250, textWidth + 120) // Min 250, +120 for icons and generous padding
        panel?.setContentSize(NSSize(width: dynamicWidth, height: 44))
        centerBottom()
        panel?.makeKeyAndOrderFront(nil)
        
        // 1 saniye sonra otomatik gizle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            hide()
        }
    }
    
    static func showError(_ text: String) {
        ensurePanelIfNeeded()
        
        // Error HUD göster
        hosting?.rootView = HUDView(mode: .error(text: text), onCopy: nil, onClose: nil)
        hosting?.needsLayout = true
        panel?.title = ""
        
        // Text uzunluğuna göre dinamik genişlik (cömert padding)
        let textWidth = text.size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium)]).width
        let dynamicWidth = max(250, textWidth + 120) // Min 250, +120 for icons and generous padding
        panel?.setContentSize(NSSize(width: dynamicWidth, height: 44))
        centerBottom()
        panel?.makeKeyAndOrderFront(nil)
        
        // 3 saniye sonra otomatik gizle
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            hide()
        }
    }
    
    static func showVoiceRecording(duration: TimeInterval, audioLevel: Float) {
        ensurePanelIfNeeded()
        
        hosting?.rootView = HUDView(mode: .voiceRecording(duration: duration, audioLevel: audioLevel), onCopy: nil, onClose: nil)
        hosting?.needsLayout = true
        panel?.title = ""
        panel?.setContentSize(NSSize(width: 320, height: 44)) // Increased width to prevent truncation
        centerBottom()
        panel?.makeKeyAndOrderFront(nil)
    }
    
    static func updateVoiceRecording(duration: TimeInterval, audioLevel: Float) {
        guard let hosting = hosting else { return }
        hosting.rootView = HUDView(mode: .voiceRecording(duration: duration, audioLevel: audioLevel), onCopy: nil, onClose: nil)
        hosting.needsLayout = true
    }
    

    static func hide(after seconds: Double = 0) {
        if seconds > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { hide() }
            return
        }
        panel?.orderOut(nil)
    }
    
    /// Force reset the HUD panel - useful for fixing state issues
    static func forceReset() {
        print("🔄 HUD: Force resetting panel...")
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
        // Panel will be recreated on next show
    }
    
    /// Hide and reset the panel completely
    static func hideAndReset() {
        print("🔄 HUD: Hiding and resetting panel...")
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
    }

    // ---- Sonuç: metni göster + Copy/Close
    static func showResult(_ resultText: String, title: String = "Promptify") {
        ensurePanelIfNeeded()
        hosting?.rootView = HUDView(mode: .result(text: resultText), onCopy: {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let ok = pasteboard.setString(resultText, forType: .string)
            if ok {
                hosting?.rootView = HUDView(mode: .progress(text: "Copied ✔"), onCopy: nil, onClose: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    hosting?.rootView = HUDView(mode: .result(text: resultText), onCopy: {
                        let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let ok = pasteboard.setString(resultText, forType: .string)
                    }, onClose: { hide() })
                }
            }
        }, onClose: {
            hide()
        })
        panel?.title = title
        panel?.setContentSize(NSSize(width: 520, height: 300))
        center()
        panel?.makeKeyAndOrderFront(nil)
    }

    // ---- Internal
    private static func updateProgress(_ text: String) {
        ensurePanelIfNeeded()
        hosting?.rootView = HUDView(mode: .progress(text: text), onCopy: nil, onClose: nil)
        hosting?.needsLayout = true
        panel?.title = ""
        
        // Text uzunluğuna göre dinamik genişlik (cömert padding)
        let textWidth = text.size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium)]).width
        let dynamicWidth = max(250, textWidth + 120) // Min 250, +120 for icons and generous padding
        panel?.setContentSize(NSSize(width: dynamicWidth, height: 44))
        centerBottom()
    }

    private static func ensurePanelIfNeeded() {
        if panel != nil { return }
        let content = HUDView(mode: .progress(text: ""))
        let hostingView = NSHostingView(rootView: content)
        hosting = hostingView

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 44),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        p.title = ""
        p.isFloatingPanel = true
        p.level = .screenSaver // En üst seviye
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.backgroundColor = NSColor.clear
        p.contentView = hostingView
        panel = p
        centerBottom()
    }

    private static func center() {
        if let screen = NSScreen.main?.visibleFrame, let p = panel {
            let x = screen.midX - p.frame.width/2
            let y = screen.midY - p.frame.height/2
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    private static func centerBottom() {
        guard let screen = NSScreen.main?.visibleFrame, let p = panel else {
            print("❌ HUD: Cannot position panel - screen or panel not available")
            return
        }
        
        let panelWidth = p.frame.width
        let panelHeight = p.frame.height
        
        // Calculate position with safety margins
        let x = max(screen.minX + 10, min(screen.midX - panelWidth/2, screen.maxX - panelWidth - 10))
        let y = max(screen.minY + 20, screen.minY + 20) // At least 20px from bottom
        
        // Ensure panel fits within screen bounds
        if x + panelWidth <= screen.maxX && y + panelHeight <= screen.maxY {
            p.setFrameOrigin(NSPoint(x: x, y: y))
            print("📍 HUD: Panel positioned at (\(x), \(y))")
        } else {
            // Fallback to center if bottom positioning fails
            let centerX = screen.midX - panelWidth/2
            let centerY = screen.midY - panelHeight/2
            p.setFrameOrigin(NSPoint(x: centerX, y: centerY))
            print("⚠️ HUD: Using center position as fallback")
        }
        
        // Make sure panel is visible
        if !p.isVisible {
            p.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - SwiftUI içerik

struct HUDView: View {
    enum Mode {
        case progress(text: String)
        case success(text: String)
        case error(text: String)
        case result(text: String)
        case voiceRecording(duration: TimeInterval, audioLevel: Float)
    }

    var mode: Mode
    var onCopy: (() -> Void)?
    var onClose: (() -> Void)?

    init(mode: Mode, onCopy: (() -> Void)? = nil, onClose: (() -> Void)? = nil) {
        self.mode = mode
        self.onCopy = onCopy
        self.onClose = onClose
    }

    var body: some View {
        switch mode {
        case .progress(let text):
            HStack(spacing: 12) {
                // Sol taraf - Icon
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.leading, 12)
                
                // Text - tam genişlik
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Progress spinner - en sağda
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                    .tint(.white.opacity(0.8))
                    .padding(.trailing, 16)
            }
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.2, blue: 0.2),
                                Color(red: 0.15, green: 0.15, blue: 0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            )
            
        case .success(let text):
            HStack(spacing: 12) {
                // Sol taraf - Icon
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.leading, 12)
                
                // Text - tam genişlik
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Checkmark - texte yakın
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: true)
                    .padding(.trailing, 16)
            }
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.2, blue: 0.2),
                                Color(red: 0.15, green: 0.15, blue: 0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            )

        case .error(let text):
            HStack(spacing: 12) {
                // Sol taraf - Error Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.leading, 12)
                
                // Text - tam genişlik
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // X mark - sağda
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red.opacity(0.9))
                    .scaleEffect(1.0)
                    .padding(.trailing, 16)
            }
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.8, green: 0.2, blue: 0.2),
                                Color(red: 0.7, green: 0.15, blue: 0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: .red.opacity(0.25), radius: 12, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            )
            
        case .result(let text):
            VStack(alignment: .leading, spacing: 8) {
                Text("Result")
                    .font(.headline)

                // Seçilebilir, kaydırılabilir metin alanı
                ScrollView {
                    TextEditor(text: .constant(text))
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .frame(minHeight: 180)
                        .disabled(true) // düzenlenmesin, sadece seçim/kopya
                }
                HStack {
                    Button("Copy to Clipboard") { onCopy?() }
                    Spacer()
                    Button("Close") { onClose?() }
                }
                .padding(.top, 6)
            }
            .frame(width: 520, height: 300)
            .padding(14)
            
        case .voiceRecording(let duration, let audioLevel):
            createVoiceRecordingView(duration: duration, audioLevel: audioLevel)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    @ViewBuilder
    private func createVoiceRecordingView(duration: TimeInterval, audioLevel: Float) -> some View {
        HStack(spacing: 16) {
            // Clean microphone icon with smooth opacity animation
            Image(systemName: "mic.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .opacity(0.25 + Double(audioLevel) * 0.75) // Daha saydamdan beyaza
                .animation(.easeInOut(duration: 0.2), value: audioLevel)
                .padding(.leading, 16)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Recording...")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                
                Text(formatDuration(duration))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: true, vertical: false) // Prevent truncation
            }
            
            Spacer()
            
            // Enhanced audio level indicator with more bars and smoother animation
            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { index in
                    let isActive = audioLevel > Float(index) * 0.1
                    let baseHeight: CGFloat = 8 + CGFloat(index) * 1.5
                    let scaleValue: CGFloat = isActive ? 
                        0.7 + CGFloat(audioLevel) * (1.0 + CGFloat(index) * 0.1) : 
                        0.7
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isActive ? 
                              Color.green.opacity(0.8 + Double(audioLevel) * 0.2) : 
                              Color.gray.opacity(0.3))
                        .frame(width: 5, height: baseHeight)
                        .scaleEffect(y: scaleValue)
                        .animation(
                            .easeOut(duration: 0.15)
                            .delay(Double(index) * 0.02),
                            value: audioLevel
                        )
                }
            }
            .padding(.trailing, 16)
        }
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.2, blue: 0.2),
                            Color(red: 0.15, green: 0.15, blue: 0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
    }
}
