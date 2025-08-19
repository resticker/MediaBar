# MediaBar

A macOS menu bar app for controlling media playback with global keyboard shortcuts and enhanced skip functionality.

## What it does

MediaBar displays current media information (title, artist, album artwork) in your menu bar and provides comprehensive playback controls through both the menu bar interface and global keyboard shortcuts.

### Key Features

- **Menu Bar Display**: Shows currently playing track info and album artwork
- **Global Keyboard Shortcuts**: Control playback from anywhere on your system
- **Skip Controls**: Skip forward/backward by customizable time intervals (not just track-to-track)
- **Configurable Skip Duration**: Set custom skip amounts (default: 5 seconds)
- **Universal Player Support**: Works with any media player that supports macOS Now Playing

## Controls Available

### Menu Bar Controls
- Play/Pause
- Previous Track
- Next Track
- Skip Backward (by seconds)
- Skip Forward (by seconds)

### Global Keyboard Shortcuts
All controls above can be assigned custom keyboard shortcuts that work system-wide:
- Play/Pause shortcut
- Previous Track shortcut  
- Next Track shortcut
- Skip Backward shortcut (by duration)
- Skip Forward shortcut (by duration)

## Settings

### Skip Duration Configuration
- **Skip Backward Duration**: Customizable seconds to skip backward (default: 5s)
- **Skip Forward Duration**: Customizable seconds to skip forward (default: 5s)

### Display Options
- Show/hide artist name
- Show/hide track title
- Show/hide album name
- Show/hide remaining time
- Hide text when paused
- Maximum display width
- Custom menu bar icons

## Supported Players

Works with any player that supports macOS Now Playing system, including:
- Apple Music/iTunes
- Spotify
- TIDAL
- Chrome (web players)
- IINA
- QuickTime Player
- And many others

## Dependencies

MediaBar uses [ungive/media-control](https://github.com/ungive/media-control) v0.6.0 for real-time media state streaming on macOS 15+. This CLI tool provides:

- **Event-driven updates**: Streams media changes as JSON for responsive UI updates
- **Complete metadata**: Track info, playback state, timing, and media type
- **macOS 15 compatibility**: Works with the latest macOS media system changes
- **Installation**: `brew install ungive/tap/media-control` (automatically handled in builds)

The app combines media-control for data streaming with PrivateMediaRemote framework for media controls and legacy compatibility.

## Building

### Prerequisites
- Xcode 16.4 or later
- macOS 15.0+ SDK
- Carthage (for dependencies)

### Build Instructions

#### Development/Debug Build
```bash
# Install dependencies
carthage update --platform macOS

# Build debug version (either scheme works)
xcodebuild -scheme MediaBar -configuration Debug clean build
# or
xcodebuild -scheme Debug -configuration Debug clean build

# Built app location:
# ~/Library/Developer/Xcode/DerivedData/MediaBar-*/Build/Products/Debug/MediaBar.app
```

#### Production/Release Build
```bash
# Install dependencies
carthage update --platform macOS

# Build optimized release version
xcodebuild -scheme MediaBar -configuration Release clean build

# Built app location:
# ~/Library/Developer/Xcode/DerivedData/MediaBar-*/Build/Products/Release/MediaBar.app
```

#### Install to Applications
```bash
# For Release build (recommended):
ditto "~/Library/Developer/Xcode/DerivedData/MediaBar-*/Build/Products/Release/MediaBar.app" /Applications/MediaBar.app

# Fix code signing for local development:
codesign --remove-signature /Applications/MediaBar.app/Contents/Frameworks/PrivateMediaRemote.framework
codesign --force --sign - /Applications/MediaBar.app/Contents/Frameworks/PrivateMediaRemote.framework  
codesign --force --sign - /Applications/MediaBar.app
```

### Build Configurations

- **Debug**: Includes debug symbols, no optimization (`-O0`), faster compile time
  - Binary size: ~56KB (single architecture) 
- **Release**: Optimized for size (`-Os`), stripped symbols, slower compile time
  - Binary size: ~793KB (universal binary: arm64 + x86_64)

**Note**: Debug builds may only include the current architecture (arm64 on Apple Silicon), while Release builds include both Intel and Apple Silicon architectures for distribution.

## TODO

### Architecture Improvements
- [ ] find and remove all timers, polling, retries, etc. that represent dirty/poor architecture
- [ ] make sure code (like media state management) is purely event-driven and reactive

