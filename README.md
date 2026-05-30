# Open YouTube Music (OpenYTMusic)

A premium, high-performance native macOS desktop client for YouTube Music, built entirely in **Pure Swift and SwiftUI** with a zero-Xcode compilation pipeline. 

Designed for elegance, lightweight memory footprint, and perfect alignment with macOS desktop aesthetics.

---

## 🎨 Key Features

- **macOS Native Aesthetics**: Premium glassmorphic window rendering (`NSVisualEffectView`) supporting automatic system-native light/dark appearance changes.
- **Pure Native Player Control Bar**: Replaces the default web-based player bar with a modern, clean, custom SwiftUI interface at the bottom.
- **Lock Screen & Media Key Integration**: Fully synchronizes track metadata (title, artist, album name, and cover artwork) with the macOS Control Center and system-wide Now Playing panel via `MPNowPlayingInfoCenter`, with full support for physical media key playback controls.
- **Menu Bar Tray Widget**: Lightweight native tray item (`NSStatusItem`) showing the active song title and a native controls menu.
- **Real-Time Scrolling Synced Lyrics**: Includes an Apple Music-style sliding sidebar panel and a QQ Music-style floating transparent desktop capsule overlay, featuring Chinese translation fallback retries and double-sided title verification.
- **Seamless Single-Page App (SPA) Navigation**: Supports interactive artist and album text hyperlinks with hover slide animations that click the underlying web engine anchors, loading pages instantly without full page reloads.
- **Fluid Timeline Scrubbing**: Direct drag-and-seek timeline progress bar that suspends playhead overrides during drags for fluid seeking.
- **Persistent User Settings**: Automatically saves and restores your lyrics scale, sidebar toggles, and floating window visibility states across app launches using standard macOS `UserDefaults`.
- **Built-in Ad Blocker**: Deploys declarative `WKContentRuleList` ad and tracker blocking lists natively to the WebKit core for zero CPU overhead.

---

## 🛠 Compilation & Launch

The project is designed with a zero-dependency, zero-Xcode build pipeline. To compile and run the application natively on your macOS machine:

1. Open your terminal in the project root directory.
2. Run the compiled build script:
   ```bash
   ./build.sh
   ```
This will compile all Swift source files, assemble the native application bundle structure (`build/Open YouTube Music.app`), convert the custom PNG app icon into macOS-native multi-resolution `.icns` files, and launch the application directly.

---

## ⚖ Trademark & Legal Disclaimer

**Open YouTube Music** (also referred to as **OpenYTMusic** or **OpenYTM**) is an **open-source, community-driven desktop utility**. 

- This application is **not affiliated with, authorized, maintained, sponsored, or endorsed** by Google LLC, YouTube, or any of their affiliates or registered trademark holders.
- YouTube and YouTube Music are registered trademarks of Google LLC.
- The use of trademarked terms, service names, or brand logos in this project or its documentation is solely for **nominative, descriptive, and compatibility purposes** to inform users of the third-party web service accessed by this open-source client under fair use guidelines. 
- All media assets, logos, and web content loaded within the client's WebKit window are streamed directly from, and remain the intellectual property of, their respective official creators and trademark holders.

---

## 📂 Project Structure

- `build.sh` — Compiling, packaging, and launch automation script.
- `src/assets/icon.png` — The custom rice-grain red ruby app icon template.
- `src/swift/main.swift` — Application entry point, App delegate lifecycle, and window management.
- `src/swift/ThemeCSS.swift` — CSS styling rules injected into WebKit.
- `src/swift/WebView.swift` — WebKit configuration, JavaScript bridge, and ad blocking filters.
- `src/swift/LyricsViews.swift` — SwiftUI Native player bar and scrollable lyrics panels.
- `src/swift/LyricsManager.swift` — LRC parser and metadata matching waterfall controller.
- `src/swift/NowPlayingManager.swift` — Media control center and physical keyboard keys hook.
- `src/swift/TrayManager.swift` — macOS Menu Bar status item widget.
