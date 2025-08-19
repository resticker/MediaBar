# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

### Development Build
```bash
# Install dependencies first
carthage update --platform macOS

# Build debug version
xcodebuild -project macos/MediaBar.xcodeproj -scheme MediaBar -configuration Debug build

# Built app location:
~/Library/Developer/Xcode/DerivedData/MediaBar-*/Build/Products/Debug/MediaBar.app
```

### Production Build
```bash
# Build optimized release version
xcodebuild -project macos/MediaBar.xcodeproj -scheme MediaBar -configuration Release build

# Built app location:
~/Library/Developer/Xcode/DerivedData/MediaBar-*/Build/Products/Release/MediaBar.app
```

### Install to Applications
```bash
# For Release build (recommended):
ditto "~/Library/Developer/Xcode/DerivedData/MediaBar-*/Build/Products/Release/MediaBar.app" /Applications/MediaBar.app

# Fix code signing for local development:
codesign --remove-signature /Applications/MediaBar.app/Contents/Frameworks/PrivateMediaRemote.framework
codesign --force --sign - /Applications/MediaBar.app/Contents/Frameworks/PrivateMediaRemote.framework  
codesign --force --sign - /Applications/MediaBar.app
```

### Dependencies
```bash
# Update Carthage dependencies
carthage update --platform macOS

# Install media-control (required for media state streaming)
brew install ungive/tap/media-control
```

## Architecture Overview

### Core Components

**GlobalState** (`macos/GlobalState.{h,m}`)
- Central state management for media information (title, artist, album, artwork, playback state)
- Integrates with `media-control` CLI tool for real-time media streaming via NSTask
- Handles JSON parsing of media data including large base64 artwork payloads with buffering
- Posts NSNotifications (`GlobalStateNotification.infoDidChange`, `GlobalStateNotification.isPlayingDidChange`)
- Manages media controls via PrivateMediaRemote framework

**AppDelegate** (`macos/AppDelegate.{h,m}`)
- Creates and manages NSStatusItem for menu bar display
- Observes GlobalState notifications to update menu bar text and artwork
- Handles multiple initialization paths (init, awakeFromNib, applicationDidFinishLaunching) with proper status item deduplication
- Implements fallback display logic ("🎵 MediaBar" when no media data)

**Media Integration**
- Uses `media-control` binary (v0.6.0) for event-driven media state streaming on macOS 15+
- Requires proper environment variables: `PATH` and `DYLD_FRAMEWORK_PATH` set in NSTask for framework loading
- PrivateMediaRemote framework for sending media commands (play/pause, skip, etc.)
- MediaRemote framework for legacy compatibility

### Key Implementation Details

**Media Control Stream Integration**
- GlobalState spawns NSTask running `media-control stream --no-diff` for real-time updates
- JSON responses buffered in `mediaControlBuffer` to handle large artwork payloads spanning multiple reads
- Environment variables must be set on NSTask: `PATH` and `DYLD_FRAMEWORK_PATH=/opt/homebrew/Frameworks`
- Stream failures captured via stderr monitoring for debugging

**Status Bar Management**
- Single status item creation handled by `setupStatusBar` method with existence checks
- Multiple initialization triggers (timer-based, XIB-based) with proper deduplication
- Display logic handles empty states with fallback text
- Artwork display integrated with text in attributed strings

**Swift Integration**
- `ShortcutDefinitions.swift` defines keyboard shortcuts using KeyboardShortcuts package
- Objective-C bridging header for mixed language support
- Swift Package Manager integration for KeyboardShortcuts dependency

### Project Structure
- `macos/` - Main Xcode project and source files
- `macos/Categories/` - Objective-C category extensions
- `macos/Preferences/` - Settings UI controllers
- `macos/Views/` - Custom UI components
- `macos/Carthage/` - Third-party framework dependencies
- `macos/Configuration/` - App configuration files and entitlements

### Critical Dependencies
- **media-control**: Real-time media state streaming (requires `brew install ungive/tap/media-control`)
- **PrivateMediaRemote**: Media playback control (Carthage dependency)
- **KeyboardShortcuts**: Global keyboard shortcut management (Swift Package Manager)
- **MediaRemote**: System media integration (Private framework)

### Debugging Media Issues
When media information isn't displaying:
1. Check media-control works independently: `/opt/homebrew/bin/media-control get`
2. Verify framework loading: Check logs for "Failed to load framework" errors
3. Ensure single status item: Look for duplicate status bar creation in logs
4. Check GlobalState notifications: Verify `infoDidChange` notifications are firing