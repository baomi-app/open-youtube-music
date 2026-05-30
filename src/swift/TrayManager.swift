import AppKit
import Foundation

class TrayManager: NSObject {
    static let shared = TrayManager()
    
    private var statusItem: NSStatusItem!
    private var currentTrackTitle = ""
    private var currentTrackArtist = ""
    private var isPlaying = false
    
    func start() {
        // Create native macOS Status Bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Use native macOS crisp SF Symbol that automatically shifts colors on dark/light menu bars
            if let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "YouTube Music") {
                image.isTemplate = true // ensures perfect blending with macOS dark/light menu bar
                button.image = image
            } else {
                button.title = "🎵"
            }
        }
        
        setupMenu()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTrackStateChanged(_:)),
            name: NSNotification.Name("TrackStateChanged"),
            object: nil
        )
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // 1. Now Playing label
        let nowPlayingItem = NSMenuItem(title: currentTrackTitle.isEmpty ? "Not Playing" : "Now Playing: \(currentTrackTitle)", action: nil, keyEquivalent: "")
        nowPlayingItem.isEnabled = false
        menu.addItem(nowPlayingItem)
        
        if !currentTrackArtist.isEmpty {
            let artistItem = NSMenuItem(title: "by \(currentTrackArtist)", action: nil, keyEquivalent: "")
            artistItem.isEnabled = false
            menu.addItem(artistItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Play / Pause Control
        let playPauseItem = NSMenuItem(
            title: isPlaying ? "Pause" : "Play",
            action: #selector(menuPlayPause),
            keyEquivalent: "p"
        )
        playPauseItem.target = self
        menu.addItem(playPauseItem)
        
        // 3. Next Track
        let nextItem = NSMenuItem(
            title: "Next Track",
            action: #selector(menuNext),
            keyEquivalent: "]"
        )
        nextItem.target = self
        menu.addItem(nextItem)
        
        // 4. Previous Track
        let prevItem = NSMenuItem(
            title: "Previous Track",
            action: #selector(menuPrev),
            keyEquivalent: "["
        )
        prevItem.target = self
        menu.addItem(prevItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Toggle Mini Player
        let miniPlayerItem = NSMenuItem(
            title: "Toggle Mini Player",
            action: #selector(menuToggleMiniPlayer),
            keyEquivalent: "m"
        )
        miniPlayerItem.target = self
        menu.addItem(miniPlayerItem)
        
        // 5b. Toggle App Sidebar Lyrics
        let sidebarLyricsItem = NSMenuItem(
            title: AppState.shared.showSidebarLyrics ? "Hide Sidebar Lyrics" : "Show Sidebar Lyrics",
            action: #selector(menuToggleSidebarLyrics),
            keyEquivalent: "l"
        )
        sidebarLyricsItem.target = self
        menu.addItem(sidebarLyricsItem)
        
        // 5c. Toggle Desktop Floating Lyrics
        let desktopLyricsItem = NSMenuItem(
            title: AppState.shared.showDesktopLyrics ? "Hide Desktop Lyrics" : "Show Desktop Lyrics",
            action: #selector(menuToggleDesktopLyrics),
            keyEquivalent: "L"
        )
        desktopLyricsItem.target = self
        menu.addItem(desktopLyricsItem)
        
        // 6. Show Window
        let showWindowItem = NSMenuItem(
            title: "Show Player",
            action: #selector(menuShowWindow),
            keyEquivalent: "s"
        )
        showWindowItem.target = self
        menu.addItem(showWindowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 7. Quit App
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(menuQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func handleTrackStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        currentTrackTitle = userInfo["title"] as? String ?? ""
        currentTrackArtist = userInfo["artist"] as? String ?? ""
        isPlaying = userInfo["playing"] as? Bool ?? false
        
        // Update menu bar title dynamically (only when playing to preserve menu bar clean aesthetics)
        if let button = statusItem.button {
            if isPlaying && !currentTrackTitle.isEmpty {
                let displayTitle = currentTrackTitle.count > 25
                    ? String(currentTrackTitle.prefix(22)) + "..."
                    : currentTrackTitle
                button.title = " " + displayTitle
            } else {
                button.title = ""
            }
        }
        
        setupMenu()
    }
    
    @objc private func menuPlayPause() {
        NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "play-pause")
    }
    
    @objc private func menuNext() {
        NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "next")
    }
    
    @objc private func menuPrev() {
        NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "prev")
    }
    
    @objc private func menuToggleMiniPlayer() {
        NotificationCenter.default.post(name: NSNotification.Name("ToggleMiniPlayer"), object: nil)
    }
    
    @objc private func menuToggleSidebarLyrics() {
        NotificationCenter.default.post(name: NSNotification.Name("ToggleSidebarLyrics"), object: nil)
    }
    
    @objc private func menuToggleDesktopLyrics() {
        NotificationCenter.default.post(name: NSNotification.Name("ToggleDesktopLyrics"), object: nil)
    }
    
    @objc private func menuShowWindow() {
        NotificationCenter.default.post(name: NSNotification.Name("ShowWindow"), object: nil)
    }
    
    @objc private func menuQuit() {
        NSApplication.shared.terminate(nil)
    }
}
