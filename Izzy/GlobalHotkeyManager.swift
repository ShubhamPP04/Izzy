//
//  GlobalHotkeyManager.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI
import Carbon
import AppKit

class GlobalHotkeyManager: ObservableObject {
    private var hotKeyRef: EventHotKeyRef?
    private let hotkeyID = EventHotKeyID(signature: OSType(0x497A7A79), id: 1) // 'Izzy'
    private var eventHandler: EventHandlerRef?
    private var lastHotkeyTime: Date = Date(timeIntervalSince1970: 0) // Initialize to epoch to prevent initial blocking
    private let hotkeyDebounceInterval: TimeInterval = 0.1 // 100ms debounce (reduced from 200ms)
    private let doublePressInterval: TimeInterval = 0.5 // 500ms window for double press detection
    private var consecutivePressCount = 0
    private var doublePressTimer: Timer?
    
    weak var windowManager: WindowManager?
    
    init() {
        setupEventHandler()
        registerGlobalHotkey()
    }
    
    deinit {
        unregisterGlobalHotkey()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        doublePressTimer?.invalidate()
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        let callback: EventHandlerProcPtr = { _, event, userData in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), 
                            nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            
            if hotkeyID.signature == manager.hotkeyID.signature && hotkeyID.id == manager.hotkeyID.id {
                DispatchQueue.main.async {
                    manager.handleHotkeyPress()
                }
                return OSStatus(noErr)
            }
            
            return OSStatus(eventNotHandledErr)
        }
        
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, 
                          Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }
    
    private func registerGlobalHotkey() {
        // Unregister any existing hotkey first
        unregisterGlobalHotkey()
        
        // Option + Space
        let keyCode = UInt32(kVK_Space)
        let modifiers = UInt32(optionKey)
        
        let status = RegisterEventHotKey(keyCode, modifiers, hotkeyID, 
                                       GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status == noErr {
            print("✅ Global hotkey registered successfully (Option + Space)")
        } else {
            print("❌ Failed to register global hotkey: \(status)")
        }
    }
    
    private func unregisterGlobalHotkey() {
        if let hotKeyRef = hotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status == noErr {
                print("✅ Global hotkey unregistered successfully")
            } else {
                print("⚠️ Failed to unregister global hotkey: \(status)")
            }
            self.hotKeyRef = nil
        }
    }
    
    private func handleHotkeyPress() {
        let currentTime = Date()
        
        // More lenient debounce - only prevent rapid successive presses
        guard currentTime.timeIntervalSince(lastHotkeyTime) > hotkeyDebounceInterval else {
            print("🚫 Hotkey press ignored (debounced) - too rapid")
            return
        }
        
        lastHotkeyTime = currentTime
        print("⌨️ Global hotkey pressed (Option + Space) at \(currentTime)")
        
        // Ensure we're on the main thread and call toggle immediately
        DispatchQueue.main.async { [weak self] in
            self?.windowManager?.toggleVisibility()
        }
    }
}