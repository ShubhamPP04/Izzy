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
        // Option + Space
        let keyCode = UInt32(kVK_Space)
        let modifiers = UInt32(optionKey)
        
        let status = RegisterEventHotKey(keyCode, modifiers, hotkeyID, 
                                       GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status != noErr {
            print("Failed to register global hotkey: \(status)")
        }
    }
    
    private func unregisterGlobalHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
    
    private func handleHotkeyPress() {
        windowManager?.toggleVisibility()
    }
}