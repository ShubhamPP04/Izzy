//
//  GlobalHotkeyManager.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI
import Carbon
import AppKit

enum HotkeyModifier: String, CaseIterable, Identifiable {
    case command
    case control
    case option

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .control: return "⌃"
        case .option: return "⌥"
        }
    }

    var displayName: String {
        switch self {
        case .command: return "Command"
        case .control: return "Control"
        case .option: return "Option"
        }
    }

    var carbonFlags: UInt32 {
        switch self {
        case .command: return UInt32(cmdKey)
        case .control: return UInt32(controlKey)
        case .option: return UInt32(optionKey)
        }
    }

    var accessibilityDescription: String {
        "\(displayName) + Space"
    }
}

class GlobalHotkeyManager: ObservableObject {
    static let hotkeyDefaultsKey = "globalHotkeyModifier"
    private var hotKeyRef: EventHotKeyRef?
    private let hotkeyID = EventHotKeyID(signature: OSType(0x497A7A79), id: 1) // 'Izzy'
    private var eventHandler: EventHandlerRef?
    private var lastHotkeyTime: Date = Date(timeIntervalSince1970: 0) // Initialize to epoch to prevent initial blocking
    private let hotkeyDebounceInterval: TimeInterval = 0.1 // 100ms debounce (reduced from 200ms)
    private let doublePressInterval: TimeInterval = 0.5 // 500ms window for double press detection
    private var consecutivePressCount = 0
    private var doublePressTimer: Timer?
    @Published private(set) var hotkeyModifier: HotkeyModifier
    @Published private(set) var lastRegistrationStatus: OSStatus = noErr
    @Published private(set) var lastFailedModifier: HotkeyModifier?
    var currentShortcutDescription: String {
        hotkeyDisplayString(for: hotkeyModifier)
    }
    
    weak var windowManager: WindowManager?
    
    init() {
        let storedModifier = UserDefaults.standard.string(forKey: Self.hotkeyDefaultsKey)
        hotkeyModifier = HotkeyModifier(rawValue: storedModifier ?? "") ?? .option
        setupEventHandler()
        registerGlobalHotkey(for: hotkeyModifier)
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
    
    @discardableResult
    private func registerGlobalHotkey(for modifier: HotkeyModifier? = nil, shouldTrackStatus: Bool = true) -> OSStatus {
        // Unregister any existing hotkey first
        unregisterGlobalHotkey()

        let selectedModifier = modifier ?? hotkeyModifier
        
        // Option + Space
        let keyCode = UInt32(kVK_Space)
        let modifiers = selectedModifier.carbonFlags
        
        let status = RegisterEventHotKey(keyCode, modifiers, hotkeyID, 
                                       GetApplicationEventTarget(), 0, &hotKeyRef)
        if shouldTrackStatus {
            lastRegistrationStatus = status
            lastFailedModifier = status == noErr ? nil : selectedModifier
        }
        
        if status == noErr {
            print("✅ Global hotkey registered successfully (\(hotkeyDisplayString(for: selectedModifier)))")
        } else {
            print("❌ Failed to register global hotkey: \(status)")
        }
        return status
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
        print("⌨️ Global hotkey pressed (\(hotkeyDisplayString(for: hotkeyModifier))) at \(currentTime)")
        
        // Ensure we're on the main thread and call toggle immediately
        DispatchQueue.main.async { [weak self] in
            self?.windowManager?.toggleVisibility()
        }
    }

    func updateHotkey(modifier: HotkeyModifier) {
        guard modifier != hotkeyModifier else { return }
        let previousModifier = hotkeyModifier
        hotkeyModifier = modifier
        UserDefaults.standard.set(modifier.rawValue, forKey: Self.hotkeyDefaultsKey)
        let status = registerGlobalHotkey(for: modifier)
        if status != noErr {
            print("⚠️ Reverting to previous hotkey (\(hotkeyDisplayString(for: previousModifier))) due to registration error: \(status)")
            lastRegistrationStatus = status
            lastFailedModifier = modifier
            hotkeyModifier = previousModifier
            UserDefaults.standard.set(previousModifier.rawValue, forKey: Self.hotkeyDefaultsKey)
            _ = registerGlobalHotkey(for: previousModifier, shouldTrackStatus: false)
        }
    }

    private func hotkeyDisplayString(for modifier: HotkeyModifier) -> String {
        "\(modifier.symbol) \(modifier.displayName) + Space"
    }
}