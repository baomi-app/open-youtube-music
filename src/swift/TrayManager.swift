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
            // Draw a gorgeous custom YouTube Music concentric-circle play logo (pixel-perfect vector)
            button.image = createTrayIcon()
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
        
        // 6b. Language (语言) - Nested Submenu
        let languageItem = NSMenuItem(title: "Language (语言)", action: nil, keyEquivalent: "")
        let langSubMenu = NSMenu()
        
        let currentLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "auto"
        
        let autoLangItem = NSMenuItem(title: "Auto (自适应)", action: #selector(menuSetLanguageAuto), keyEquivalent: "")
        autoLangItem.target = self
        autoLangItem.state = currentLang == "auto" ? .on : .off
        langSubMenu.addItem(autoLangItem)
        
        let zhLangItem = NSMenuItem(title: "简体中文 (Chinese)", action: #selector(menuSetLanguageZh), keyEquivalent: "")
        zhLangItem.target = self
        zhLangItem.state = currentLang == "zh-CN" ? .on : .off
        langSubMenu.addItem(zhLangItem)
        
        let enLangItem = NSMenuItem(title: "English (English)", action: #selector(menuSetLanguageEn), keyEquivalent: "")
        enLangItem.target = self
        enLangItem.state = currentLang == "en" ? .on : .off
        langSubMenu.addItem(enLangItem)
        
        languageItem.submenu = langSubMenu
        menu.addItem(languageItem)
        
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
    
    @objc private func menuSetLanguageAuto() {
        UserDefaults.standard.set("auto", forKey: "appLanguage")
        NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
        setupMenu()
    }
    
    @objc private func menuSetLanguageZh() {
        UserDefaults.standard.set("zh-CN", forKey: "appLanguage")
        NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
        setupMenu()
    }
    
    @objc private func menuSetLanguageEn() {
        UserDefaults.standard.set("en", forKey: "appLanguage")
        NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
        setupMenu()
    }
    
    private func createTrayIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            
            let center = CGPoint(x: rect.midX, y: rect.midY)
            
            // 1. Draw solid outer circle (filled)
            context.setBlendMode(.normal)
            let outerPath = CGMutablePath()
            outerPath.addArc(center: center, radius: 8.0, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            context.addPath(outerPath)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            
            // 2. Erase the inner circle to create a transparent gap (cutout)
            context.setBlendMode(.clear)
            let innerPath = CGMutablePath()
            innerPath.addArc(center: center, radius: 5.5, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            context.addPath(innerPath)
            context.fillPath()
            
            // 3. Draw the solid center play triangle
            context.setBlendMode(.normal)
            let triPath = CGMutablePath()
            triPath.move(to: CGPoint(x: center.x - 1.3, y: center.y + 2.2))
            triPath.addLine(to: CGPoint(x: center.x - 1.3, y: center.y - 2.2))
            triPath.addLine(to: CGPoint(x: center.x + 2.5, y: center.y))
            triPath.closeSubpath()
            context.addPath(triPath)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            
            return true
        }
        image.isTemplate = true
        return image
    }
}
