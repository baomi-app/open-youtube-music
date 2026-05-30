import Cocoa
import SwiftUI

// Observable App State for SwiftUI Views
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isMiniPlayer = false
    
    // Lyrics States
    @Published var showSidebarLyrics: Bool {
        didSet {
            UserDefaults.standard.set(showSidebarLyrics, forKey: "showSidebarLyrics")
        }
    }
    @Published var showDesktopLyrics: Bool {
        didSet {
            UserDefaults.standard.set(showDesktopLyrics, forKey: "showDesktopLyrics")
        }
    }
    @Published var lyricsScale: Double {
        didSet {
            UserDefaults.standard.set(lyricsScale, forKey: "lyricsScale")
        }
    }
    
    @Published var lyricLines: [LyricLine] = []
    @Published var activeLyricIndex: Int? = nil
    @Published var lyricsLoading = false
    
    // Playback States
    @Published var trackTitle = "Not Playing"
    @Published var trackArtist = ""
    @Published var trackAlbum = ""
    @Published var trackAlbumArt = ""
    @Published var isPlaying = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    
    init() {
        let savedSidebar = UserDefaults.standard.object(forKey: "showSidebarLyrics") as? Bool ?? false
        let savedDesktop = UserDefaults.standard.object(forKey: "showDesktopLyrics") as? Bool ?? false
        let savedScale = UserDefaults.standard.double(forKey: "lyricsScale")
        
        self.showSidebarLyrics = savedSidebar
        self.showDesktopLyrics = savedDesktop
        self.lyricsScale = savedScale > 0 ? savedScale : 1.0
    }
}

// SwiftUI Content Root View
struct ContentView: View {
    @ObservedObject var state = AppState.shared
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                WebView(
                    url: URL(string: "https://music.youtube.com/")!,
                    isMiniPlayer: $state.isMiniPlayer
                )
                .edgesIgnoringSafeArea(.all)
                
                if !state.isMiniPlayer {
                    NativePlayerBarView()
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            // Side lyrics panel in Apple Music style
            if state.showSidebarLyrics && !state.isMiniPlayer {
                SidebarLyricsView()
            }
        }
    }
}

// Application Delegate Lifecycle Handler
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var desktopLyricsWindow: NSWindow?
    var normalBounds = NSRect(x: 0, y: 0, width: 1200, height: 800)
    
    private var currentTitle = ""
    private var currentArtist = ""
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 1. Create the main player window
        window = NSWindow(
            contentRect: normalBounds,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.delegate = self
        
        // 2. Configure vibrant glassmorphism (frosted effect)
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .underWindowBackground
        
        // 3. Inject SwiftUI View
        let hostingView = NSHostingView(rootView: ContentView())
        
        visualEffect.frame = window.contentView!.bounds
        visualEffect.autoresizingMask = [.width, .height]
        
        hostingView.frame = visualEffect.bounds
        hostingView.autoresizingMask = [.width, .height]
        
        visualEffect.addSubview(hostingView)
        window.contentView = visualEffect
        
        // 4. Premium macOS frameless and transparent styles
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        
        // Force dark mode window appearance to completely eliminate white titlebar background on light system themes
        if #available(macOS 10.14, *) {
            window.appearance = NSAppearance(named: .darkAqua)
        } else {
            window.appearance = NSAppearance(named: .vibrantDark)
        }
        
        // 5. App positioning
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 6. Create the Desktop Floating Lyrics Window (QQ Music style)
        createDesktopLyricsWindow()
        if AppState.shared.showDesktopLyrics {
            self.desktopLyricsWindow?.orderFrontRegardless()
        }
        
        
        // 7. Start Managers
        NowPlayingManager.shared.start()
        TrayManager.shared.start()
        
        // 8. Setup Notifications
        setupNotificationObservers()
        
        // 9. Setup standard macOS Menu Bar (Enables standard Cmd+C, Cmd+V hotkeys)
        setupMainMenu()
        
        // 10. Automatically trigger visual snapshot for AI diagnosis
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            print("📸 Diagnostic: Triggering automatic TakeSnapshot...")
            NotificationCenter.default.post(name: NSNotification.Name("TakeSnapshot"), object: nil)
        }
    }
    
    private func createDesktopLyricsWindow() {
        // Transparent, borderless, floating window
        let lyricsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 160),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        lyricsWindow.isOpaque = false
        lyricsWindow.backgroundColor = .clear
        lyricsWindow.hasShadow = false
        lyricsWindow.isMovableByWindowBackground = true // Drag anywhere on window background to reposition!
        lyricsWindow.level = .statusBar // Float above normal windows, overlays, and menubar
        lyricsWindow.ignoresMouseEvents = false // Allow clicking and dragging the window
        lyricsWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        lyricsWindow.isReleasedWhenClosed = false
        
        // Inject DesktopLyricsView SwiftUI component
        let hosting = NSHostingView(rootView: DesktopLyricsView())
        hosting.wantsLayer = true // CRITICAL: Layer-backing forces AppKit to render contents of completely transparent window!
        lyricsWindow.contentView = hosting
        
        // Align at bottom center of the main display Visible area
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.width - 1200) / 2
            let y = screenRect.origin.y + 40 // 40px above dock/bottom edge
            lyricsWindow.setFrame(NSRect(x: x, y: y, width: 1200, height: 160), display: true)
        }
        
        self.desktopLyricsWindow = lyricsWindow
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TakeSnapshot"),
            object: nil,
            queue: .main
        ) { _ in
            guard let window = self.window else { return }
            let view = window.contentView!
            let bounds = view.bounds
            
            guard let imageRep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return }
            view.cacheDisplay(in: bounds, to: imageRep)
            
            let image = NSImage(size: bounds.size)
            image.addRepresentation(imageRep)
            
            if let data = imageRep.representation(using: .png, properties: [:]) {
                let path = "/Users/arjenzhou/.gemini/antigravity/brain/db24375b-8fa0-4eb8-a647-d1c35fc93021/window_snapshot.png"
                do {
                    try data.write(to: URL(fileURLWithPath: path))
                    print("📸 diagnostic_snapshot: Saved window render to \(path)")
                } catch {
                    print("✗ diagnostic_snapshot error: \(error)")
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowWindow"),
            object: nil,
            queue: .main
        ) { _ in
            self.showWindow()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ToggleMiniPlayer"),
            object: nil,
            queue: .main
        ) { _ in
            self.toggleMiniPlayer()
        }
        
        // Sidebar Lyrics Toggle Observer
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ToggleSidebarLyrics"),
            object: nil,
            queue: .main
        ) { _ in
            AppState.shared.showSidebarLyrics.toggle()
        }
        
        // Desktop Lyrics Toggle Observer
        // Desktop Lyrics Toggle Observer
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ToggleDesktopLyrics"),
            object: nil,
            queue: .main
        ) { _ in
            AppState.shared.showDesktopLyrics.toggle()
            let active = AppState.shared.showDesktopLyrics
            
            if active {
                self.desktopLyricsWindow?.orderFrontRegardless()
            } else {
                self.desktopLyricsWindow?.orderOut(nil)
            }
            
            // Sync custom Web player bar toggle button state
            let js = "if (window.updateDesktopLyricsButton) { window.updateDesktopLyricsButton(\(active)); }"
            WebView.sharedWebView?.evaluateJavaScript(js, completionHandler: nil)
        }
        
        // Desktop Lyrics Auto Width Observer
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UpdateDesktopLyricsWindowWidth"),
            object: nil,
            queue: .main
        ) { notification in
            if let width = notification.object as? Double {
                self.adjustDesktopLyricsWindowWidth(width)
            }
        }
        
        // Track playhead time/track state observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTrackStateChanged(_:)),
            name: NSNotification.Name("TrackStateChanged"),
            object: nil
        )
    }
    
    @objc private func handleTrackStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        let title = userInfo["title"] as? String ?? ""
        let artist = userInfo["artist"] as? String ?? ""
        let album = userInfo["album"] as? String ?? ""
        let duration = userInfo["duration"] as? Double ?? 0.0
        let currentTime = userInfo["currentTime"] as? Double ?? 0.0
        let albumArt = userInfo["albumArt"] as? String ?? ""
        let playing = userInfo["playing"] as? Bool ?? false
        
        // Update central published properties for SwiftUI native control bar
        DispatchQueue.main.async {
            AppState.shared.trackTitle = title.isEmpty ? "Not Playing" : title
            AppState.shared.trackArtist = artist
            AppState.shared.trackAlbum = album
            AppState.shared.trackAlbumArt = albumArt
            AppState.shared.isPlaying = playing
            AppState.shared.currentTime = currentTime
            AppState.shared.duration = duration
        }
        
        // If song changed, trigger asynchronous lyrics fetch
        if title != currentTitle || artist != currentArtist {
            currentTitle = title
            currentArtist = artist
            
            AppState.shared.lyricsLoading = true
            AppState.shared.lyricLines = []
            AppState.shared.activeLyricIndex = nil
            
            LyricsManager.shared.fetchSyncedLyrics(title: title, artist: artist, duration: duration) { lines in
                DispatchQueue.main.async {
                    AppState.shared.lyricsLoading = false
                    if let lines = lines {
                        AppState.shared.lyricLines = lines
                    }
                }
            }
        }
        
        // If lyrics are loaded, update active line index based on playback head time
        if !AppState.shared.lyricLines.isEmpty {
            let lines = AppState.shared.lyricLines
            var activeIndex: Int? = nil
            for (index, line) in lines.enumerated() {
                if line.time <= currentTime {
                    activeIndex = index
                } else {
                    break
                }
            }
            if activeIndex != AppState.shared.activeLyricIndex {
                AppState.shared.activeLyricIndex = activeIndex
            }
        }
    }
    
    func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func toggleMiniPlayer() {
        AppState.shared.isMiniPlayer.toggle()
        
        if AppState.shared.isMiniPlayer {
            // Save normal size
            normalBounds = window.frame
            
            // Transform into tiny floating widget
            window.level = .floating
            window.setFrame(NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: 340, height: 340), display: true, animate: true)
            window.aspectRatio = NSSize(width: 1, height: 1)
        } else {
            // Restore normal window
            window.level = .normal
            window.aspectRatio = NSSize(width: 0, height: 0) // unlock aspect ratio
            window.setFrame(normalBounds, display: true, animate: true)
        }
    }
    
    private func adjustDesktopLyricsWindowWidth(_ width: Double) {
        guard let lyricsWindow = self.desktopLyricsWindow,
              let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        // Add 60px extra padding for perfect visual layout padding
        let paddedWidth = width + 60.0
        let targetWidth = min(screenRect.width - 80, max(400.0, paddedWidth))
        
        let currentFrame = lyricsWindow.frame
        // Expand symmetrically around the current horizontal center (respects user dragging!)
        let currentCenterX = currentFrame.origin.x + currentFrame.width / 2.0
        let newX = currentCenterX - targetWidth / 2.0
        let newY = currentFrame.origin.y // Keep the bottom edge stationary
        
        let scale = AppState.shared.lyricsScale
        let targetHeight = 160.0 * scale
        
        let newFrame = NSRect(x: newX, y: newY, width: targetWidth, height: targetHeight)
        
        // Update frame instantly to avoid jittery/sliding window frame animations!
        lyricsWindow.setFrame(newFrame, display: true, animate: false)
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        appMenu.addItem(NSMenuItem(title: "About Open YouTube Music", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Hide Open YouTube Music", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Open YouTube Music", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // Edit Menu
        let editMenu = NSMenu(title: "Edit")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        
        // Window Menu (CRITICAL: macOS maps Cmd+W to window close via mainMenu!)
        let windowMenu = NSMenu(title: "Window")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    // NSWindowDelegate: Hide instead of close on close button click
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window.orderOut(nil)
        return false
    }
    
    // Re-open window when Dock icon is clicked
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }
}

// -------------------------------------------------------------
// Pure Swift App Bootstrap Entry Point
// -------------------------------------------------------------
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
