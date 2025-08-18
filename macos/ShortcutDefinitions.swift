import Foundation
import KeyboardShortcuts

// Extension to define keyboard shortcut names for MediaBar
extension KeyboardShortcuts.Name {
    static let playPause = Self("playPause", default: .init(.space, modifiers: [.command, .shift]))
    static let previousTrack = Self("previousTrack", default: .init(.leftArrow, modifiers: [.command, .shift]))
    static let nextTrack = Self("nextTrack", default: .init(.rightArrow, modifiers: [.command, .shift]))
    static let skipBackward = Self("skipBackward", default: .init(.leftArrow, modifiers: [.command, .option]))
    static let skipForward = Self("skipForward", default: .init(.rightArrow, modifiers: [.command, .option]))
}

// Objective-C bridge class to interact with KeyboardShortcuts from Objective-C code
@objc public class MediaBarShortcuts: NSObject {
    
    @MainActor @objc public static let shared = MediaBarShortcuts()
    
    @objc public func setupGlobalShortcuts(playPauseAction: @escaping () -> Void,
                                          previousAction: @escaping () -> Void,
                                          nextAction: @escaping () -> Void,
                                          skipBackwardAction: @escaping () -> Void,
                                          skipForwardAction: @escaping () -> Void) {
        
        KeyboardShortcuts.onKeyUp(for: .playPause) {
            playPauseAction()
        }
        
        KeyboardShortcuts.onKeyUp(for: .previousTrack) {
            previousAction()
        }
        
        KeyboardShortcuts.onKeyUp(for: .nextTrack) {
            nextAction()
        }
        
        KeyboardShortcuts.onKeyUp(for: .skipBackward) {
            skipBackwardAction()
        }
        
        KeyboardShortcuts.onKeyUp(for: .skipForward) {
            skipForwardAction()
        }
    }
    
    @objc public func reset() {
        KeyboardShortcuts.reset(.playPause)
        KeyboardShortcuts.reset(.previousTrack)
        KeyboardShortcuts.reset(.nextTrack)
        KeyboardShortcuts.reset(.skipBackward)
        KeyboardShortcuts.reset(.skipForward)
    }
    
    @MainActor @objc public func createRecorderForShortcutType(_ shortcutType: String) -> Any? {
        print("🔧 Creating recorder for shortcut type: \(shortcutType)")
        guard let shortcutName = shortcutNameFromString(shortcutType) else {
            print("❌ Unknown shortcut type: \(shortcutType)")
            return nil
        }
        
        print("✅ Creating KeyboardShortcuts.RecorderCocoa for: \(shortcutName)")
        let recorder = KeyboardShortcuts.RecorderCocoa(for: shortcutName)
        print("🎯 Recorder created successfully: \(recorder)")
        return recorder
    }
    
    private func shortcutNameFromString(_ shortcutType: String) -> KeyboardShortcuts.Name? {
        switch shortcutType {
        case "playPause":
            return .playPause
        case "previousTrack":
            return .previousTrack
        case "nextTrack":
            return .nextTrack
        case "skipBackward":
            return .skipBackward
        case "skipForward":
            return .skipForward
        default:
            return nil
        }
    }
}