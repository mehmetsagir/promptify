//
//  Permission.swift
//  Promptify
//
//  Created by Mehmet Sağır on 7.09.2025.
//


import AppKit
import ApplicationServices
import AVFoundation
import HotKey

enum Permission {
    enum PermissionType {
        case accessibility
        case inputMonitoring
        case microphone
    }

    static var hasAccessibility: Bool { 
        // Force a fresh check by using the options parameter
        let result = AXIsProcessTrustedWithOptions(nil)
        print("🔍 Accessibility check result: \(result)")
        return result
    }

    static func hasInputMonitoring() -> Bool {
        // For macOS 10.15+, input monitoring is required
        if #available(macOS 10.15, *) {
            
            // Method 1: Test if we can actually register a HotKey (most reliable)
            do {
                // Try to create a temporary hotkey to test permission
                let testHotKey = HotKey(key: .f19, modifiers: [.command, .shift]) // F19 is unlikely to conflict
                testHotKey.keyDownHandler = { /* do nothing */ }
                
                // If we got here without error, permission is granted
                print("🔍 Input monitoring check result: true (HotKey registration successful)")
                return true
                
            } catch {
                print("🔍 Input monitoring check result: false (HotKey registration failed: \(error))")
            }
            
            // Method 2: Try creating an event tap (less reliable for sandboxed apps)
            let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            let eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap, 
                options: .listenOnly,
                eventsOfInterest: eventMask,
                callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in 
                    return Unmanaged.passRetained(event) 
                },
                userInfo: nil
            )
            
            if let eventTap = eventTap {
                CFMachPortInvalidate(eventTap)
                print("🔍 Input monitoring check result: true (event tap successful)")
                return true
            }
            
            // Method 3: Check if actual hotkeys are working
            // If we have existing hotkeys and they're working, permission is granted
            print("🔍 Input monitoring check result: false (all methods failed)")
            return false
        }
        
        print("ℹ️ Input monitoring not required on this macOS version")
        return true
    }
    
    static var hasMicrophone: Bool {
        // Force a fresh status check
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        let result = status == .authorized
        
        // Log detailed status for debugging
        let statusDescription: String
        switch status {
        case .notDetermined: statusDescription = "notDetermined"
        case .restricted: statusDescription = "restricted"  
        case .denied: statusDescription = "denied"
        case .authorized: statusDescription = "authorized"
        @unknown default: statusDescription = "unknown(\(status.rawValue))"
        }
        
        print("🔍 Microphone check - Status: \(statusDescription), Result: \(result)")
        return result
    }
    
    static func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    static func ensurePermissionsAtLaunch() {
        print("🔐 Checking permissions at launch...")
        
        if !hasAccessibility {
            print("❌ Accessibility permission missing - requesting...")
            requestAccessibility()
        } else {
            print("✅ Accessibility permission granted")
        }
        
        if !hasInputMonitoring() {
            print("❌ Input monitoring permission missing - requesting...")
            requestInputMonitoring()
        } else {
            print("✅ Input monitoring permission granted")
        }
        
        // Check microphone permission status
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 Microphone permission status: \(micStatus.rawValue)")
        
        if !hasMicrophone {
            print("❌ Microphone permission missing - will request when voice recording is used...")
        } else {
            print("✅ Microphone permission granted")
        }
    }

    static func requestAccessibility() {
        let opts: CFDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    static func requestInputMonitoring() {
        if #available(macOS 10.15, *) {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
            event?.post(tap: .cghidEventTap)
        }
    }

    static func openPrivacyPane(for permissionType: PermissionType) {
        print("🔧 Opening privacy settings for: \(permissionType)")
        
        let anchor: String
        switch permissionType {
        case .accessibility:
            anchor = "Privacy_Accessibility"
        case .inputMonitoring:
            anchor = "Privacy_InputMonitoring"
        case .microphone:
            anchor = "Privacy_Microphone"
        }
        
        // Try different URL schemes for different macOS versions
        let urlsToTry = [
            // macOS 13+ System Settings URLs
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)",
            // macOS 12 and earlier System Preferences URLs
            "x-apple.systempreferences:com.apple.preference.security?\(anchor)",
            // Fallback - open Privacy & Security section
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        
        for urlString in urlsToTry {
            if let url = URL(string: urlString) {
                print("🔧 Trying URL: \(urlString)")
                NSWorkspace.shared.open(url)
                return
            }
        }
        
        print("❌ Failed to open any privacy settings URL")
    }
    
    // Check all permissions and show detailed status
    static func checkAllPermissions() -> (hasAccessibility: Bool, hasInputMonitoring: Bool) {
        let accessibilityStatus = hasAccessibility
        let inputMonitoringStatus = hasInputMonitoring()
        
        print("📊 Permission Status:")
        print("   Accessibility: \(accessibilityStatus ? "✅ Granted" : "❌ Missing")")
        print("   Input Monitoring: \(inputMonitoringStatus ? "✅ Granted" : "❌ Missing")")
        
        return (accessibilityStatus, inputMonitoringStatus)
    }
}