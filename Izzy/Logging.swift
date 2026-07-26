//
//  Logging.swift
//  Izzy
//
//  Module-scoped `print` shim.
//
//  Izzy logs heavily on hot paths: every playback tick, every Python service
//  response, every search result row. Each `Swift.print` performs a write(2) to
//  stdout, which is unbuffered for a GUI process — a syscall per call site, on
//  the main thread, in a shipping build where nobody reads the output.
//
//  Declaring `print` at module scope shadows `Swift.print` for every file in the
//  Izzy target, so Release builds pay one static Bool test instead of a syscall.
//  No existing call site had to be touched.
//
//  Release logging is not gone, just off by default: launch with IZZY_VERBOSE=1
//  to get the full stream back for diagnosis.
//
//      IZZY_VERBOSE=1 /Applications/Izzy.app/Contents/MacOS/Izzy
//

import Foundation

#if DEBUG

@inline(__always)
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    Swift.print(items.map { "\($0)" }.joined(separator: separator), terminator: terminator)
}

#else

/// Resolved once at launch; the optimizer folds the check into a cheap load.
let izzyVerboseLogging = ProcessInfo.processInfo.environment["IZZY_VERBOSE"] != nil

@inline(__always)
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    guard izzyVerboseLogging else { return }
    Swift.print(items.map { "\($0)" }.joined(separator: separator), terminator: terminator)
}

#endif
