import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    @Binding var isMiniPlayer: Bool
    
    // Static storage for shared reference so managers can communicate
    static var sharedWebView: WKWebView? = nil
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // 1. Setup declarative native adblocker rule lists
        setupAdBlocker(config)
        
        // 2. Setup JS-to-Swift Message Bridge
        let userContentController = config.userContentController
        userContentController.add(context.coordinator, name: "YTMBridge")
        
        // Console logger injection for early diagnostic feedback
        let consoleLoggerSource = """
        (function() {
            var originalLog = console.log;
            var originalError = console.error;
            var originalWarn = console.warn;
            
            console.log = function() {
                var msg = Array.from(arguments).map(String).join(' ');
                originalLog.apply(console, arguments);
                try {
                    window.webkit.messageHandlers.YTMBridge.postMessage({ debug: "[LOG] " + msg });
                } catch(e) {}
            };
            
            console.error = function() {
                var msg = Array.from(arguments).map(String).join(' ');
                originalError.apply(console, arguments);
                try {
                    window.webkit.messageHandlers.YTMBridge.postMessage({ debug: "[ERROR] " + msg });
                } catch(e) {}
            };
            
            console.warn = function() {
                var msg = Array.from(arguments).map(String).join(' ');
                originalWarn.apply(console, arguments);
                try {
                    window.webkit.messageHandlers.YTMBridge.postMessage({ debug: "[WARN] " + msg });
                } catch(e) {}
            };
            
            window.addEventListener('error', function(e) {
                try {
                    window.webkit.messageHandlers.YTMBridge.postMessage({ 
                        debug: "[UNHANDLED ERROR] " + e.message + " at " + e.filename + ":" + e.lineno 
                    });
                } catch(err) {}
            });
        })();
        """
        let consoleLoggerScript = WKUserScript(source: consoleLoggerSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(consoleLoggerScript)
        
        // 3. Inject CSS Theme (Base64-encoded to guarantee zero character escaping/syntax errors, safely prepended to documentElement using MutationObserver at earliest millisecond!)
        let base64CSS = Data(ThemeCSS.css.utf8).base64EncodedString()
        let cssSource = """
        (function() {
            var style = document.createElement('style');
            style.id = 'ytm-native-theme-css';
            style.textContent = atob('\(base64CSS)');
            
            function checkAndAppend() {
                var parent = document.head || document.documentElement;
                if (parent) {
                    if (!document.getElementById('ytm-native-theme-css')) {
                        parent.appendChild(style);
                    }
                    return true;
                }
                return false;
            }
            
            if (!checkAndAppend()) {
                var observer = new MutationObserver(function() {
                    if (checkAndAppend()) {
                        observer.disconnect();
                    }
                });
                observer.observe(document, { childList: true, subtree: true });
            }
        })();
        """
        let cssScript = WKUserScript(source: cssSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(cssScript)
        
        // 4. Inject Playback Monitor JS (streams currentTime and duration for synced lyrics, and injects custom player buttons)
        let jsMonitor = """
        // Define global status update function
        window.updateDesktopLyricsButton = function(active) {
            var btn = document.getElementById('desktop-lyrics-toggle-btn');
            if (btn) {
                btn.setAttribute('data-active', active ? 'true' : 'false');
                if (active) {
                    btn.style.color = '#ff4d4f'; // Beautiful glowing soft red
                    btn.style.opacity = '1';
                    btn.style.filter = 'drop-shadow(0 0 4px rgba(255, 77, 79, 0.6))';
                } else {
                    btn.style.color = '#ffffff';
                    btn.style.opacity = '0.5';
                    btn.style.filter = 'none';
                }
            }
        };

        setInterval(function() {
            try {
                var playerBar = document.querySelector('ytmusic-player-bar');
                var root = playerBar ? (playerBar.shadowRoot || playerBar) : document;
                

                
                var btn = document.getElementById('desktop-lyrics-toggle-btn');
                var rightControls = root.querySelector('.right-controls-buttons') || 
                                    root.querySelector('#right-controls') || 
                                    root.querySelector('.right-controls') ||
                                    document.querySelector('ytmusic-player-bar .right-controls-buttons');
                
                if (rightControls) {
                    // Resilient check: If button exists but is no longer inside rightControls container, clean and re-inject
                    if (btn && !rightControls.contains(btn)) {
                        btn.remove();
                        btn = null;
                    }
                    
                    if (!btn) {
                        var newBtn = document.createElement('button');
                        newBtn.id = 'desktop-lyrics-toggle-btn';
                        newBtn.className = 'style-scope ytmusic-player-bar';
                        newBtn.style.background = 'none';
                        newBtn.style.border = 'none';
                        newBtn.style.padding = '0';
                        newBtn.style.margin = '0 8px';
                        newBtn.style.cursor = 'pointer';
                        newBtn.style.outline = 'none';
                        newBtn.style.transition = 'all 0.3s ease';
                        newBtn.style.display = 'inline-flex';
                        newBtn.style.alignItems = 'center';
                        newBtn.style.justifyContent = 'center';
                        newBtn.style.verticalAlign = 'middle';
                        
                        newBtn.style.color = '#ffffff';
                        newBtn.style.opacity = '0.5';
                        newBtn.setAttribute('data-active', 'false');
                        newBtn.title = "Toggle Floating Desktop Lyrics";
                        
                        var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
                        svg.setAttribute('viewBox', '0 0 24 24');
                        svg.setAttribute('width', '22');
                        svg.setAttribute('height', '22');
                        svg.style.fill = 'currentColor';
                        
                        var svgPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
                        svgPath.setAttribute('d', 'M20 3H4c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h6v2H8v2h8v-2h-2v-2h6c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 12H4V5h16v10zM6 7h12v2H6zm0 4h8v2H6z');
                        
                        svg.appendChild(svgPath);
                        newBtn.appendChild(svg);
                        
                        newBtn.addEventListener('mouseenter', function() {
                            newBtn.style.opacity = newBtn.getAttribute('data-active') === 'true' ? '1' : '0.8';
                        });
                        newBtn.addEventListener('mouseleave', function() {
                            newBtn.style.opacity = newBtn.getAttribute('data-active') === 'true' ? '1' : '0.5';
                        });
                        
                        newBtn.addEventListener('click', function(e) {
                            e.preventDefault();
                            e.stopPropagation();
                            window.webkit.messageHandlers.YTMBridge.postMessage({
                                event: "toggleDesktopLyrics"
                            });
                        });
                        
                        rightControls.insertBefore(newBtn, rightControls.firstChild);
                        
                        // Request initial sync of button state from Swift
                        window.webkit.messageHandlers.YTMBridge.postMessage({
                            event: "syncDesktopLyricsButton"
                        });
                    }
                    
                    // Periodic debugging log for container children
                    if (Math.random() < 0.05) {
                        var childrenIds = Array.from(rightControls.children).map(function(c) {
                            return (c.tagName || '') + '#' + (c.id || '') + '.' + (c.className || '').split(' ').join('.');
                        }).join(' | ');
                        window.webkit.messageHandlers.YTMBridge.postMessage({
                            debug: "Container children: " + childrenIds
                        });
                    }
                }

                var title = "";
                var artist = "";
                var album = "";
                var albumArt = "";
                
                // 1. Primary retrieval from MediaSession API (highly reliable, matches browser metadata)
                if (navigator.mediaSession && navigator.mediaSession.metadata) {
                    title = navigator.mediaSession.metadata.title || "";
                    artist = navigator.mediaSession.metadata.artist || "";
                    album = navigator.mediaSession.metadata.album || "";
                    if (navigator.mediaSession.metadata.artwork && navigator.mediaSession.metadata.artwork.length > 0) {
                        var artwork = navigator.mediaSession.metadata.artwork;
                        albumArt = artwork[artwork.length - 1].src || "";
                    }
                }
                
                // 2. Secondary fallback via DOM query selector (supporting shadowRoot polymer encapsulation)
                if (!title || !artist) {
                    var titleEl = root.querySelector('.title') || document.querySelector('ytmusic-player-bar .title');
                    var bylineEl = root.querySelector('.byline') || document.querySelector('ytmusic-player-bar .byline') || root.querySelector('.subtitle');
                    
                    if (titleEl) title = titleEl.textContent.trim();
                    if (bylineEl) artist = bylineEl.textContent.trim();
                    
                    if (!albumArt) {
                        var albumArtImg = root.querySelector('img.image') || root.querySelector('.image') || document.querySelector('ytmusic-player-bar img.image') || root.querySelector('#thumbnail img');
                        if (albumArtImg) albumArt = albumArtImg.src;
                    }
                }
                
                // Robust triple-fallback for album
                if (!album) {
                    var byline = root.querySelector('.byline') || document.querySelector('ytmusic-player-bar .byline');
                    if (byline) {
                        // First fallback: search through links inside the byline
                        var links = byline.querySelectorAll('a');
                        for (var i = 0; i < links.length; i++) {
                            var href = links[i].getAttribute('href') || "";
                            if (href.indexOf('browse/MPRE') !== -1 || href.indexOf('album/') !== -1) {
                                album = links[i].innerText.trim();
                                break;
                            }
                        }
                        // Second fallback: split text by dot (e.g. Artist • Album • Year)
                        if (!album) {
                            var parts = byline.innerText.split('•');
                            if (parts.length >= 2) {
                                album = parts[1].trim();
                            }
                        }
                    }
                }
                
                var video = document.querySelector('video');
                var currentTime = video && !isNaN(video.currentTime) ? video.currentTime : 0;
                var duration = video && !isNaN(video.duration) ? video.duration : 0;
                
                var playing = false;
                if (navigator.mediaSession) {
                    playing = navigator.mediaSession.playbackState === 'playing';
                }
                if (!playing && video) {
                    playing = !video.paused && !video.ended;
                }
                
                window.webkit.messageHandlers.YTMBridge.postMessage({
                    title: title,
                    artist: artist,
                    album: album,
                    albumArt: albumArt,
                    playing: playing,
                    currentTime: currentTime,
                    duration: duration
                });
            } catch(e) {
                window.webkit.messageHandlers.YTMBridge.postMessage({
                    debug: "Monitor interval error: " + e.message
                });
            }
        }, 500);
        
        // Handle native macOS window dragging from the custom top nav bar
        document.addEventListener('mousedown', function(e) {
            var navBar = document.querySelector('ytmusic-nav-bar');
            if (navBar && navBar.contains(e.target)) {
                var interactive = e.target.closest('button, input, a, [role="button"], #search-box, .search-container, ytmusic-search-box');
                if (!interactive) {
                    window.webkit.messageHandlers.YTMBridge.postMessage({
                        event: "dragWindow"
                    });
                }
            }
        });
        """
        let monitorScript = WKUserScript(source: jsMonitor, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(monitorScript)
        
        config.userContentController = userContentController
        
        // 5. Instantiate WebKit View
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // 6. User Agent Spoofing (Allows standard Google account logins)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        
        // 7. Configure background transparency
        webView.setValue(false, forKey: "drawsBackground") // equivalent to transparent background in Electron
        
        WebView.sharedWebView = webView
        
        // Load initial page
        let request = URLRequest(url: url)
        webView.load(request)
        
        // Register observer for commands from tray/keys
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MediaCommand"),
            object: nil,
            queue: .main
        ) { notification in
            if let command = notification.object as? String {
                self.executeCommand(command, on: webView)
            }
        }
        
        // Register observer to jump/seek to specific time click on lyrics!
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SeekToTime"),
            object: nil,
            queue: .main
        ) { notification in
            if let time = notification.object as? Double {
                let js = "var video = document.querySelector('video'); if (video) { video.currentTime = \(time); }"
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
        
        // Register observer to navigate to the current song's artist
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToArtist"),
            object: nil,
            queue: .main
        ) { _ in
            let js = """
            (function() {
                var playerBar = document.querySelector('ytmusic-player-bar');
                var root = playerBar ? (playerBar.shadowRoot || playerBar) : document;
                var byline = root.querySelector('.byline') || document.querySelector('ytmusic-player-bar .byline');
                if (byline) {
                    var links = byline.querySelectorAll('a');
                    for (var i = 0; i < links.length; i++) {
                        var href = links[i].getAttribute('href') || "";
                        if (href.indexOf('channel/') !== -1 || href.indexOf('browse/UC') !== -1) {
                            links[i].click();
                            return true;
                        }
                    }
                }
                return false;
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        // Register observer to navigate to the current song's album
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToAlbum"),
            object: nil,
            queue: .main
        ) { _ in
            let js = """
            (function() {
                var playerBar = document.querySelector('ytmusic-player-bar');
                var root = playerBar ? (playerBar.shadowRoot || playerBar) : document;
                var byline = root.querySelector('.byline') || document.querySelector('ytmusic-player-bar .byline');
                if (byline) {
                    var links = byline.querySelectorAll('a');
                    for (var i = 0; i < links.length; i++) {
                        var href = links[i].getAttribute('href') || "";
                        if (href.indexOf('browse/MPRE') !== -1 || href.indexOf('album/') !== -1) {
                            links[i].click();
                            return true;
                        }
                    }
                }
                return false;
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        // 8. Disable native elastic scroll bounce to prevent background bleed-through
        disableBouncing(in: webView)
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Handle transitions to Mini Player style on the DOM
        let miniPlayerClass = isMiniPlayer ? "add" : "remove"
        let js = "document.documentElement.classList.\(miniPlayerClass)('mini-player-active');"
        nsView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    private func executeCommand(_ command: String, on webView: WKWebView) {
        var js = ""
        switch command {
        case "play-pause":
            js = "document.querySelector('ytmusic-player-bar #play-pause-button').click();"
        case "next":
            js = "document.querySelector('ytmusic-player-bar .next-button').click();"
        case "prev":
            js = "document.querySelector('ytmusic-player-bar .previous-button').click();"
        default:
            return
        }
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    private func setupAdBlocker(_ config: WKWebViewConfiguration) {
        let adRules = """
        [
            {
                "trigger": { "url-filter": ".*doubleclick\\\\.net.*" },
                "action": { "type": "block" }
            },
            {
                "trigger": { "url-filter": ".*googleadservices\\\\.com.*" },
                "action": { "type": "block" }
            },
            {
                "trigger": { "url-filter": ".*googlesyndication\\\\.com.*" },
                "action": { "type": "block" }
            },
            {
                "trigger": { "url-filter": ".*/pagead/.*" },
                "action": { "type": "block" }
            },
            {
                "trigger": { "url-filter": ".*/api/stats/ads.*" },
                "action": { "type": "block" }
            },
            {
                "trigger": { "url-filter": ".*/ptracking.*" },
                "action": { "type": "block" }
            }
        ]
        """
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "NativeYTMAdBlocker",
            encodedContentRuleList: adRules
        ) { ruleList, error in
            if let ruleList = ruleList {
                config.userContentController.add(ruleList)
                print("✓ WKContentRuleList AdBlocker active.")
            } else if let error = error {
                print("✗ Failed to load WebKit AdBlocker: \(error.localizedDescription)")
            }
        }
    }
    
    private func disableBouncing(in view: NSView) {
        if let scrollView = view as? NSScrollView {
            scrollView.horizontalScrollElasticity = .none
            scrollView.verticalScrollElasticity = .none
        }
        for subview in view.subviews {
            disableBouncing(in: subview)
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        // Receive messages from JS
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "YTMBridge",
                  let dict = message.body as? [String: Any] else { return }
            
            // 1. Handle debug messages and return immediately to prevent wiping out track info
            if let debugMsg = dict["debug"] as? String {
                print("🐞 JS Debug: \(debugMsg)")
                return
            }
            
            // 2. Handle bridge events and return immediately
            if let event = dict["event"] as? String {
                if event == "dragWindow" {
                    DispatchQueue.main.async {
                        if let window = message.webView?.window,
                           let currentEvent = NSApplication.shared.currentEvent {
                            window.performDrag(with: currentEvent)
                        }
                    }
                } else if event == "toggleDesktopLyrics" {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("ToggleDesktopLyrics"), object: nil)
                    }
                } else if event == "syncDesktopLyricsButton" {
                    DispatchQueue.main.async {
                        let active = AppState.shared.showDesktopLyrics
                        let js = "if (window.updateDesktopLyricsButton) { window.updateDesktopLyricsButton(\(active)); }"
                        message.webView?.evaluateJavaScript(js, completionHandler: nil)
                    }
                }
                return
            }
            
            // 3. Handle standard track state updates
            let title = dict["title"] as? String ?? ""
            let artist = dict["artist"] as? String ?? ""
            let album = dict["album"] as? String ?? ""
            let albumArt = dict["albumArt"] as? String ?? ""
            let playing = dict["playing"] as? Bool ?? false
            let currentTime = dict["currentTime"] as? Double ?? 0.0
            let duration = dict["duration"] as? Double ?? 0.0
            
            // Post notification with track state
            let trackState: [String: Any] = [
                "title": title,
                "artist": artist,
                "album": album,
                "albumArt": albumArt,
                "playing": playing,
                "currentTime": currentTime,
                "duration": duration
            ]
            NotificationCenter.default.post(name: NSNotification.Name("TrackStateChanged"), object: nil, userInfo: trackState)
        }
        
        // Handle window.open() popups (e.g. 2-Step Verification frames) by loading them in-place
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
        
        // Open external links in macOS default browser
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                let urlString = url.absoluteString
                // Deny loading links that leave YouTube Music, open in external browser
                if navigationAction.navigationType == .linkActivated && !urlString.contains("music.youtube.com") && !urlString.contains("accounts.google.com") {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
