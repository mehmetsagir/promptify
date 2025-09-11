import SwiftUI
import AppKit

struct HotkeyRecorder: NSViewRepresentable {
    @Binding var key: String
    @Binding var modifiers: Int
    @State private var isRecording = false
    
    func makeNSView(context: Context) -> HotkeyRecorderView {
        let view = HotkeyRecorderView()
        view.onHotkeyRecorded = { newKey, newModifiers in
            key = newKey
            modifiers = newModifiers
        }
        return view
    }
    
    func updateNSView(_ nsView: HotkeyRecorderView, context: Context) {
        nsView.updateDisplay(key: key, modifiers: modifiers)
    }
}

class HotkeyRecorderView: NSView {
    var onHotkeyRecorded: ((String, Int) -> Void)?
    private var isRecording = false
    private var currentKey = ""
    private var currentModifiers = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 6
    }
    
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        isRecording = true
        needsDisplay = true
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return super.resignFirstResponder()
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        
        let modifierFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let keyCode = event.keyCode
        
        // Escape ile iptal
        if keyCode == 53 { // Escape
            window?.makeFirstResponder(nil)
            return
        }
        
        // Key'i karaktere çevir
        if let key = keyCodeToString(keyCode) {
            currentKey = key
            currentModifiers = Int(modifierFlags.rawValue)
            
            onHotkeyRecorded?(currentKey, currentModifiers)
            window?.makeFirstResponder(nil)
        }
        // Modifier tuşları için özel işlem - sadece Cmd tuşu için
        else if keyCode == 55 || keyCode == 54 { // Left Cmd or Right Cmd
            currentKey = "cmd"
            currentModifiers = Int(modifierFlags.rawValue)
            
            onHotkeyRecorded?(currentKey, currentModifiers)
            window?.makeFirstResponder(nil)
        }
    }
    
    override func flagsChanged(with event: NSEvent) {
        needsDisplay = true
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        switch keyCode {
        case 0: return "a"
        case 1: return "s"
        case 2: return "d"
        case 3: return "f"
        case 4: return "h"
        case 5: return "g"
        case 6: return "z"
        case 7: return "x"
        case 8: return "c"
        case 9: return "v"
        case 11: return "b"
        case 12: return "q"
        case 13: return "w"
        case 14: return "e"
        case 15: return "r"
        case 16: return "y"
        case 17: return "t"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 31: return "o"
        case 32: return "u"
        case 34: return "i"
        case 35: return "p"
        case 37: return "l"
        case 38: return "j"
        case 39: return "'"
        case 40: return "k"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "n"
        case 46: return "m"
        case 47: return "."
        case 49: return "space"
        default: return nil
        }
    }
    
    func updateDisplay(key: String, modifiers: Int) {
        currentKey = key
        currentModifiers = modifiers
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let text: String
        if isRecording {
            text = "Press keys..."
        } else if !currentKey.isEmpty {
            text = hotkeyDisplayString(currentModifiers, key: currentKey)
        } else {
            text = "Click to record shortcut"
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        attributedString.draw(in: textRect)
    }
    
    private func hotkeyDisplayString(_ modifiers: Int, key: String) -> String {
        var parts: [String] = []
        
        if modifiers & Int(NSEvent.ModifierFlags.command.rawValue) != 0 {
            parts.append("⌘")
        }
        if modifiers & Int(NSEvent.ModifierFlags.option.rawValue) != 0 {
            parts.append("⌥")
        }
        if modifiers & Int(NSEvent.ModifierFlags.control.rawValue) != 0 {
            parts.append("⌃")
        }
        if modifiers & Int(NSEvent.ModifierFlags.shift.rawValue) != 0 {
            parts.append("⇧")
        }
        
        // "cmd" için özel gösterim
        if key == "cmd" {
            parts.append("Cmd")
        } else if key == "space" {
            parts.append("Space")
        } else {
            parts.append(key.uppercased())
        }
        
        return parts.joined()
    }
}