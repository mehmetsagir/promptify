import AppKit
import Carbon
import ApplicationServices

enum ClipboardHelper {
    // Try to read selected text using Accessibility API, with optional clipboard fallback
    static func readSelectionStrict(allowClipboardFallback: Bool = true) -> (text: String?, diag: String) {
        // Try to read selected text using Accessibility API
        if let selectedText = axReadSelectedText() {
            return (selectedText, "AX:selected (\(selectedText.count) chars)")
        }
        
        // Fallback: try copying selection to clipboard
        let originalClipboard = NSPasteboard.general.string(forType: .string)
        let originalChangeCount = NSPasteboard.general.changeCount
        
        // Simulate Cmd+C to copy selection (multiple attempts)
        for attempt in 1...2 {
            KeyboardHelper.keyDownUp(cmd: true, key: kVK_ANSI_C)
            
            // Wait for clipboard to update (progressive wait)
            usleep(UInt32(50_000 * attempt)) // 50ms, then 100ms
            
            // Check if clipboard changed
            let newChangeCount = NSPasteboard.general.changeCount
            if newChangeCount > originalChangeCount,
               let newText = NSPasteboard.general.string(forType: .string),
               !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               newText != originalClipboard {
                return (newText, "Cmd+C:copied (\(newText.count) chars) attempt \(attempt)")
            }
        }
        
        // If Cmd+C didn't work but we have existing clipboard content, use it as fallback (if allowed)
        if allowClipboardFallback,
           let existingText = originalClipboard, 
           !existingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (existingText, "Clipboard:existing (\(existingText.count) chars)")
        }
        
        return (nil, "No text found - AX API failed and Cmd+C didn't capture new content")
    }
    
    // Read only from clipboard without trying to copy selection
    static func readClipboardOnly() -> (text: String?, diag: String) {
        let pb = NSPasteboard.general
        
        // Mevcut clipboard içeriğini kontrol et
        if let existingText = pb.string(forType: .string), 
           !existingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (existingText, "Clipboard:existing (\(existingText.count) chars)")
        }
        
        return (nil, "Clipboard:empty - Please copy some text first")
    }

    // 2) Panoya yaz ve doğrula
    @discardableResult
    static func writeAndVerify(_ s: String) -> Bool {
        let pb = NSPasteboard.general
        let before = pb.changeCount
        pb.clearContents()
        pb.declareTypes([.string], owner: nil)
        _ = pb.setString(s, forType: .string)
        for _ in 0..<12 { usleep(40_000); if pb.changeCount > before { return (pb.string(forType: .string) ?? "") == s } }
        return (pb.string(forType: .string) ?? "") == s
    }
    
    // Paste text into the currently focused application
    @discardableResult
    static func pasteIntoApplication() -> Bool {
        // Simulate Cmd+V to paste from clipboard
        KeyboardHelper.paste()
        usleep(50_000) // Wait 50ms for paste to complete
        return true
    }
    
    // Replace selected text with enhanced text
    @discardableResult
    static func replaceSelectedText(_ enhancedText: String) -> Bool {
        // First try to copy the enhanced text to clipboard
        guard writeAndVerify(enhancedText) else { return false }
        
        // Try to replace selected text directly using AX API
        if replaceSelectedTextAX(enhancedText) {
            return true
        }
        
        // Fallback: paste using Cmd+V (text is already in clipboard)
        KeyboardHelper.paste()
        usleep(50_000) // Wait 50ms for paste to complete
        return true
    }
    
    private static func replaceSelectedTextAX(_ newText: String) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        
        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard result == .success, let element = focusedElement else { return false }
        
        // Try to set the selected text directly
        let axElement = unsafeBitCast(element, to: AXUIElement.self)
        let setResult = AXUIElementSetAttributeValue(axElement, kAXSelectedTextAttribute as CFString, newText as CFString)
        return setResult == .success
    }

    // ---- AX helper: selectedText → yoksa selectedTextRange + value
    static func axReadSelectedText() -> String? {
        let sys = AXUIElementCreateSystemWide()
        var appCF: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedApplicationAttribute as CFString, &appCF) == .success,
              let appCF else { 
            print("AX Debug: Could not get focused app")
            return nil 
        }
        let app: AXUIElement = unsafeBitCast(appCF, to: AXUIElement.self)

        var uiCF: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &uiCF) == .success,
              let uiCF else { 
            print("AX Debug: Could not get focused UI element")
            return nil 
        }
        let ui: AXUIElement = unsafeBitCast(uiCF, to: AXUIElement.self)

        // Try selectedText first (most reliable)
        var txtCF: CFTypeRef?
        if AXUIElementCopyAttributeValue(ui, kAXSelectedTextAttribute as CFString, &txtCF) == .success,
           let s = txtCF as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("AX Debug: Got selected text directly: '\(s)'")
            return s
        } else {
            print("AX Debug: No direct selected text available")
        }
        
        // Try selectedTextRange + value approach
        var rangeCF: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ui, "AXSelectedTextRange" as CFString, &rangeCF) == .success,
              let rangeVal = rangeCF, CFGetTypeID(rangeVal) == AXValueGetTypeID() else { 
            print("AX Debug: Could not get selected text range")
            return nil 
        }
        let axValue = unsafeBitCast(rangeVal, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else { 
            print("AX Debug: Range value is not CFRange type")
            return nil 
        }
        var rng = CFRange()
        AXValueGetValue(axValue, .cfRange, &rng)
        print("AX Debug: Got range: location=\(rng.location), length=\(rng.length)")

        // Check if there's actually selected text (length > 0)
        guard rng.length > 0 else {
            print("AX Debug: Range length is 0, no selection")
            return nil
        }

        var valueCF: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ui, kAXValueAttribute as CFString, &valueCF) == .success,
              let full = valueCF as? String, rng.location >= 0,
              rng.location + rng.length <= full.utf16.count else { 
            print("AX Debug: Could not get full text value or range is invalid")
            return nil 
        }
        
        let start = full.index(full.startIndex, offsetBy: rng.location)
        let end = full.index(start, offsetBy: rng.length)
        let selectedText = String(full[start..<end])
        let trimmedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty else {
            print("AX Debug: Extracted text is empty or whitespace only")
            return nil
        }
        
        print("AX Debug: Extracted from range: '\(selectedText)'")
        return selectedText
    }
}

enum KeyboardHelper {
    static func keyDownUp(cmd: Bool = false, key: Int) {
        let src = CGEventSource(stateID: .hidSystemState)
        let flags: CGEventFlags = cmd ? .maskCommand : []
        let down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(key), keyDown: true); down?.flags = flags
        let up   = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(key), keyDown: false); up?.flags = flags
        down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
    }
    static func paste() { keyDownUp(cmd: true, key: kVK_ANSI_V) }
}