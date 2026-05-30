import Cocoa
import SwiftUI

// Observable App State for SwiftUI Views
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var appLanguage: String = "auto"
    
    @Published var isMiniPlayer = false
    @Published var isTransitioning = false
    
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
    @Published var matchedTitle = ""
    @Published var matchedArtist = ""
    @Published var searchResults: [LyricSearchResult] = []
    @Published var lyricsOffset: Double = 0.0
    
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
        self.appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "auto"
    }
    
    func updateLanguage() {
        DispatchQueue.main.async {
            self.appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "auto"
        }
    }
    
    func getActiveLanguageCode() -> String {
        let saved = self.appLanguage
        if saved == "auto" {
            let systemLang = Locale.preferredLanguages.first ?? "zh-CN"
            return systemLang.hasPrefix("zh") ? "zh-CN" : "en"
        }
        return saved
    }
    
    func loc(_ key: String) -> String {
        let lang = getActiveLanguageCode()
        let isZh = lang.hasPrefix("zh")
        
        switch key {
        case "Not Playing": return isZh ? "未在播放" : "Not Playing"
        case "Now Playing: ": return isZh ? "正在播放：" : "Now Playing: "
        case "by ": return isZh ? "歌手：" : "by "
        case "Play": return isZh ? "播放" : "Play"
        case "Pause": return isZh ? "暂停" : "Pause"
        case "Next Track": return isZh ? "下一首" : "Next Track"
        case "Previous Track": return isZh ? "上一首" : "Previous Track"
        case "Toggle Mini Player": return isZh ? "切换迷你播放器" : "Toggle Mini Player"
        case "Show Sidebar Lyrics": return isZh ? "显示侧边栏歌词" : "Show Sidebar Lyrics"
        case "Hide Sidebar Lyrics": return isZh ? "隐藏侧边栏歌词" : "Hide Sidebar Lyrics"
        case "Show Desktop Lyrics": return isZh ? "显示桌面歌词" : "Show Desktop Lyrics"
        case "Hide Desktop Lyrics": return isZh ? "隐藏桌面歌词" : "Hide Desktop Lyrics"
        case "Show Player": return isZh ? "显示主界面" : "Show Player"
        case "Language (语言)": return isZh ? "界面语言" : "Language"
        case "Auto (自适应)": return isZh ? "系统默认" : "Auto (System)"
        case "简体中文 (Chinese)": return isZh ? "简体中文" : "Chinese"
        case "English (English)": return isZh ? "English" : "English"
        case "Quit": return isZh ? "退出" : "Quit"
        
        case "Lyrics": return isZh ? "歌词" : "Lyrics"
        case "Matched: ": return isZh ? "已匹配：" : "Matched: "
        case "Search": return isZh ? "搜索" : "Search"
        case "Clear": return isZh ? "清除" : "Clear"
        case "正在获取歌词...": return isZh ? "正在获取歌词..." : "Fetching lyrics..."
        case "暂无同步歌词": return isZh ? "暂无同步歌词" : "No synced lyrics"
        case "暂无歌词": return isZh ? "暂无歌词" : "No lyrics"
        case "手动搜索歌词": return isZh ? "手动搜索歌词" : "Manual Search"
        case "Delay Lyrics (+0.5s)": return isZh ? "歌词延后 (+0.5秒)" : "Delay Lyrics (+0.5s)"
        case "Advance Lyrics (-0.5s)": return isZh ? "歌词提前 (-0.5秒)" : "Advance Lyrics (-0.5s)"
        case "Reset": return isZh ? "重置" : "Reset"
        case "Search Results (": return isZh ? "搜索结果 (" : "Search Results ("
        
        case "Small (80%)": return isZh ? "较小 (80%)" : "Small (80%)"
        case "Normal (100%)": return isZh ? "标准 (100%)" : "Normal (100%)"
        case "Large (120%)": return isZh ? "较大 (120%)" : "Large (120%)"
        case "Extra Large (150%)": return isZh ? "超大 (150%)" : "Extra Large (150%)"
        case "Huge (180%)": return isZh ? "巨大 (180%)" : "Huge (180%)"
        
        case "Searching...": return isZh ? "正在搜索..." : "Searching..."
        case "No results": return isZh ? "无结果" : "No results"
        case "Search failed": return isZh ? "搜索失败" : "Search failed"
        case "Network error": return isZh ? "网络错误" : "Network error"
        
        case "Search song, artist, alias...": return isZh ? "搜索歌名、歌手、别名..." : "Search song, artist, alias..."
        case "Show Album Cover": return isZh ? "显示专辑封面" : "Show Album Cover"
        case "Show Lyrics": return isZh ? "显示歌词" : "Show Lyrics"
        case "Exit Mini Player": return isZh ? "退出迷你播放器" : "Exit Mini Player"
        case "Lyrics Font Size": return isZh ? "歌词字体大小" : "Lyrics Font Size"
        case "Lyrics Sync Offset": return isZh ? "歌词同步微调" : "Lyrics Sync Offset"
        
        default: return key
        }
    }
    
    // Custom search function to be triggered manually
    func triggerCustomSearch(query: String) {
        guard !query.isEmpty else { return }
        
        self.lyricsLoading = true
        self.lyricLines = []
        self.activeLyricIndex = nil
        self.matchedTitle = "Searching..."
        self.matchedArtist = "'\(query)'"
        
        let targetTitle = self.trackTitle
        let targetArtist = self.trackArtist
        let targetDuration = self.duration
        
        LyricsManager.shared.fetchSyncedLyricsCustom(query: query, duration: targetDuration) { [weak self] lines, mTitle, mArtist in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Prevent race conditions: check if the user has skipped the song in the meantime
                guard targetTitle == self.trackTitle && targetArtist == self.trackArtist else {
                    print("⚠️ Ignoring stale custom lyrics fetch result (Current playing is '\(self.trackTitle)' by '\(self.trackArtist)')")
                    return
                }
                
                self.lyricsLoading = false
                if let lines = lines {
                    self.lyricLines = lines
                    self.matchedTitle = mTitle ?? query
                    self.matchedArtist = mArtist ?? "Manual Match"
                } else {
                    // Custom search returned no results
                    self.lyricLines = []
                    self.matchedTitle = "No results"
                    self.matchedArtist = "for '\(query)'"
                }
            }
        }
    }
    
    // Custom search list function to be triggered manually, returning a list of candidates
    func triggerSearchList(query: String) {
        guard !query.isEmpty else { return }
        
        self.lyricsLoading = true
        self.searchResults = []
        self.matchedTitle = "Searching..."
        self.matchedArtist = "'\(query)'"
        
        let targetTitle = self.trackTitle
        let targetArtist = self.trackArtist
        
        LyricsManager.shared.searchSyncedLyrics(query: query) { [weak self] results in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Prevent race conditions
                guard targetTitle == self.trackTitle && targetArtist == self.trackArtist else {
                    print("⚠️ Ignoring stale search list fetch result (Current playing is '\(self.trackTitle)' by '\(self.trackArtist)')")
                    return
                }
                
                self.lyricsLoading = false
                if let results = results {
                    self.searchResults = results
                    if results.isEmpty {
                        self.matchedTitle = "No results"
                        self.matchedArtist = "for '\(query)'"
                    } else {
                        self.matchedTitle = "Found \(results.count) results"
                        self.matchedArtist = "for '\(query)'"
                    }
                } else {
                    self.searchResults = []
                    self.matchedTitle = "Search failed"
                    self.matchedArtist = "Network error"
                }
            }
        }
    }
    
    // Selecting and loading a specific candidate from the search results
    func selectSearchResult(_ result: LyricSearchResult) {
        let parsed = LyricsManager.shared.parseLRC(result.syncedLyrics)
        if !parsed.isEmpty {
            self.lyricLines = parsed
            self.matchedTitle = result.trackName
            self.matchedArtist = result.artistName
            self.searchResults = [] // Clear search results list
        }
    }
}

struct ContentView: View {
    @ObservedObject var state = AppState.shared
    
    var body: some View {
        ZStack {
            // Main Player Layout (WebView + Player Bar + Sidebar Lyrics)
            // Kept mounted at all times to prevent state reset or WKWebView recreation
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    WebView(
                        url: URL(string: "https://music.youtube.com/")!,
                        isMiniPlayer: $state.isMiniPlayer
                    )
                    .edgesIgnoringSafeArea(.all)
                    
                    if state.showSidebarLyrics && !state.isMiniPlayer {
                        HStack(spacing: 0) {
                            Spacer()
                            SidebarLyricsView()
                                .frame(width: 320)
                                .padding(.top, 64)
                                .padding(.bottom, 0)
                        }
                        .transition(.move(edge: .trailing))
                    }
                }
                
                NativePlayerBarView()
                    .frame(height: state.isMiniPlayer ? 0 : 68)
                    .opacity(state.isMiniPlayer ? 0 : 1)
                    .clipped()
            }
            .opacity(state.isMiniPlayer ? 0 : (state.isTransitioning ? 0.3 : 1))
            .animation(.easeInOut(duration: 0.15), value: state.isMiniPlayer)
            .animation(.easeInOut(duration: 0.15), value: state.isTransitioning)
            .disabled(state.isMiniPlayer)
            
            // Native Mini Player View overlay
            if state.isMiniPlayer || state.isTransitioning {
                NativeMiniPlayerView()
                    .opacity(state.isTransitioning ? 0 : 1)
                    .animation(.easeInOut(duration: 0.15), value: state.isTransitioning)
                    .transition(.opacity)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// Application Delegate Lifecycle Handler
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var desktopLyricsWindow: NSWindow?
    var normalBounds = NSRect(x: 0, y: 0, width: 1200, height: 800)
    
    private var currentTitle = ""
    private var currentArtist = ""
    private var hasValidDurationFetched = false
    
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
    }
    
    private func createDesktopLyricsWindow() {
        // Transparent, borderless, floating panel that doesn't activate the parent app on click
        let lyricsWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 160),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
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
        
        // If song changed or valid duration finally arrived, trigger asynchronous lyrics fetch
        let songChanged = (title != currentTitle || artist != currentArtist)
        
        if (songChanged && !title.isEmpty) || (!hasValidDurationFetched && duration > 0 && !title.isEmpty) {
            if songChanged {
                currentTitle = title
                currentArtist = artist
                hasValidDurationFetched = (duration > 0)
                
                AppState.shared.lyricsLoading = true
                AppState.shared.lyricLines = []
                AppState.shared.activeLyricIndex = nil
                AppState.shared.matchedTitle = ""
                AppState.shared.matchedArtist = ""
                AppState.shared.searchResults = []
                AppState.shared.lyricsOffset = 0.0
            } else {
                print("🔄 Retroactively fetching lyrics with newly loaded valid duration: \(duration)s")
                hasValidDurationFetched = true
            }
            
            let targetTitle = title
            let targetArtist = artist
            LyricsManager.shared.fetchSyncedLyrics(title: title, artist: artist, duration: duration) { lines, mTitle, mArtist in
                DispatchQueue.main.async {
                    // Prevent race conditions: only update if the active playing song has not changed
                    guard targetTitle == AppState.shared.trackTitle && targetArtist == AppState.shared.trackArtist else {
                        print("⚠️ Ignoring stale lyrics fetch result for '\(targetTitle)' by '\(targetArtist)' (Current playing is '\(AppState.shared.trackTitle)' by '\(AppState.shared.trackArtist)')")
                        return
                    }
                    if let lines = lines {
                        AppState.shared.lyricsLoading = false
                        AppState.shared.lyricLines = lines
                        AppState.shared.matchedTitle = mTitle ?? ""
                        AppState.shared.matchedArtist = mArtist ?? ""
                    } else if songChanged {
                        // Keep loading as true if we are expecting a retry with a valid duration
                        if duration > 0 {
                            AppState.shared.lyricsLoading = false
                        }
                    } else {
                        AppState.shared.lyricsLoading = false
                    }
                }
            }
        }
        
        // If lyrics are loaded, update active line index based on playback head time + offset
        if !AppState.shared.lyricLines.isEmpty {
            let lines = AppState.shared.lyricLines
            let adjustedTime = currentTime + AppState.shared.lyricsOffset
            var activeIndex: Int? = nil
            for (index, line) in lines.enumerated() {
                if line.time <= adjustedTime {
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
        if AppState.shared.isMiniPlayer {
            // 1. Exiting Mini Player: Start transition & restore normal window size FIRST
            AppState.shared.isTransitioning = true
            AppState.shared.isMiniPlayer = false // Toggle state instantly to show full layout
            
            window.level = .normal
            window.aspectRatio = NSSize(width: 0, height: 0) // unlock aspect ratio
            window.setFrame(normalBounds, display: true, animate: false)
            
            // 2. Instantly unhide the webpage elements in WebKit
            let js = "document.documentElement.classList.remove('mini-player-active');"
            WebView.sharedWebView?.evaluateJavaScript(js, completionHandler: nil)
            
            // 3. Let the NativeMiniPlayerView fade out for 150ms, then turn off transitioning flag
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                AppState.shared.isTransitioning = false
            }
        } else {
            // 1. Entering Mini Player: Toggle the state first so SwiftUI prepares the mini layout
            AppState.shared.isMiniPlayer = true
            
            // 2. Save normal size
            normalBounds = window.frame
            
            // 3. Resize window instantly
            window.level = .floating
            window.setFrame(NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: 340, height: 340), display: true, animate: false)
            window.aspectRatio = NSSize(width: 1, height: 1)
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
setbuf(stdout, nil)
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
