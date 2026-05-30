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
            var playerBar = document.querySelector('ytmusic-player-bar');
            var root = playerBar ? (playerBar.shadowRoot || playerBar) : document;
            var btn = root.querySelector('#desktop-lyrics-toggle-btn') || document.getElementById('desktop-lyrics-toggle-btn');
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
                
                // Resiliently sync the mini-player-active class based on window size
                var isMiniSize = window.innerWidth > 0 && window.innerWidth <= 360;
                if (isMiniSize) {
                    if (!document.documentElement.classList.contains('mini-player-active')) {
                        document.documentElement.classList.add('mini-player-active');
                    }
                } else {
                    if (document.documentElement.classList.contains('mini-player-active')) {
                        document.documentElement.classList.remove('mini-player-active');
                    }
                }


                // Inject premium CSS directly into player bar shadow DOM for Mini Player mode
                var shadowStyleId = 'ytm-mini-player-shadow-css';
                if (document.documentElement.classList.contains('mini-player-active')) {
                    if (playerBar && playerBar.shadowRoot && !playerBar.shadowRoot.getElementById(shadowStyleId)) {
                        var style = document.createElement('style');
                        style.id = shadowStyleId;
                        style.textContent = `
                            :host {
                                display: flex !important;
                                flex-direction: column !important;
                                justify-content: space-between !important;
                                align-items: center !important;
                                padding: 24px 16px !important;
                                box-sizing: border-box !important;
                                height: 100vh !important;
                                min-height: 100vh !important;
                                max-height: 100vh !important;
                                width: 100vw !important;
                                background: rgba(10, 10, 10, 0.98) !important;
                            }
                            .left-content {
                                display: flex !important;
                                flex-direction: column !important;
                                align-items: center !important;
                                justify-content: center !important;
                                width: 100% !important;
                                flex: 1 !important;
                                margin: 0 !important;
                                padding: 0 !important;
                            }
                            .left-content .image, 
                            .left-content #thumbnail, 
                            .left-content .thumbnail, 
                            .left-content ytmusic-image-overlay,
                            .left-content .image-wrapper,
                            .left-content img {
                                width: 160px !important;
                                height: 160px !important;
                                min-width: 160px !important;
                                min-height: 160px !important;
                                max-width: 160px !important;
                                max-height: 160px !important;
                                border-radius: 14px !important;
                                box-shadow: 0 12px 36px rgba(0, 0, 0, 0.6) !important;
                                margin: 0 auto 16px auto !important;
                                display: block !important;
                                visibility: visible !important;
                                opacity: 1 !important;
                            }
                            .left-content img {
                                object-fit: cover !important;
                            }
                            .left-content .title-mask, 
                            .left-content .byline {
                                max-width: 280px !important;
                                overflow: hidden !important;
                                text-overflow: ellipsis !important;
                                white-space: nowrap !important;
                                text-align: center !important;
                            }
                            .left-content .title {
                                font-size: 16px !important;
                                font-weight: 700 !important;
                                color: #ffffff !important;
                                margin-bottom: 4px !important;
                                text-align: center !important;
                            }
                            .left-content .byline {
                                font-size: 13px !important;
                                color: rgba(255, 255, 255, 0.6) !important;
                                text-align: center !important;
                            }
                            .middle-content {
                                display: flex !important;
                                flex-direction: row !important;
                                align-items: center !important;
                                justify-content: center !important;
                                width: 100% !important;
                                margin: 12px 0 !important;
                                padding: 0 !important;
                            }
                            .middle-content .playback-buttons {
                                display: flex !important;
                                flex-direction: row !important;
                                align-items: center !important;
                                justify-content: center !important;
                            }
                            .middle-content tp-yt-paper-icon-button,
                            .middle-content yt-icon-button {
                                margin: 0 12px !important;
                                color: #ffffff !important;
                                opacity: 0.8 !important;
                                transition: all 0.2s ease !important;
                            }
                            .middle-content tp-yt-paper-icon-button:hover,
                            .middle-content yt-icon-button:hover {
                                opacity: 1 !important;
                                transform: scale(1.1) !important;
                            }
                            #play-pause-button {
                                background: #ffffff !important;
                                color: #000000 !important;
                                border-radius: 50% !important;
                                width: 44px !important;
                                height: 44px !important;
                                padding: 8px !important;
                                opacity: 1 !important;
                                display: inline-flex !important;
                                align-items: center !important;
                                justify-content: center !important;
                                box-shadow: 0 4px 12px rgba(255, 255, 255, 0.3) !important;
                            }
                            .right-content {
                                position: absolute !important;
                                top: 12px !important;
                                right: 12px !important;
                                width: auto !important;
                                flex-direction: row !important;
                                z-index: 100 !important;
                                display: flex !important;
                                margin: 0 !important;
                                padding: 0 !important;
                            }
                            .right-content > *:not(.expand-button):not(#expand-button) {
                                display: none !important;
                            }
                            .right-content .expand-button,
                            .right-content #expand-button {
                                display: inline-flex !important;
                                color: #ffffff !important;
                                opacity: 0.6 !important;
                                cursor: pointer !important;
                                transition: opacity 0.2s ease !important;
                            }
                            .right-content .expand-button:hover,
                            .right-content #expand-button:hover {
                                opacity: 1 !important;
                            }
                            #progress-bar, 
                            tp-yt-paper-slider, 
                            .slider-container {
                                position: absolute !important;
                                bottom: 0 !important;
                                left: 0 !important;
                                width: 100% !important;
                                height: 4px !important;
                                padding: 0 !important;
                                margin: 0 !important;
                            }
                        `;
                        playerBar.shadowRoot.appendChild(style);
                    }
                } else {
                    if (playerBar && playerBar.shadowRoot) {
                        var existingStyle = playerBar.shadowRoot.getElementById(shadowStyleId);
                        if (existingStyle) {
                            existingStyle.remove();
                        }
                    }
                }

                
                var btn = root.querySelector('#desktop-lyrics-toggle-btn') || document.getElementById('desktop-lyrics-toggle-btn');
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
                        svg.setAttribute('fill', 'none');
                        svg.setAttribute('stroke', 'currentColor');
                        svg.setAttribute('stroke-width', '2');
                        svg.setAttribute('stroke-linecap', 'round');
                        svg.setAttribute('stroke-linejoin', 'round');
                        
                        var circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
                        circle.setAttribute('cx', '7');
                        circle.setAttribute('cy', '16');
                        circle.setAttribute('r', '2');
                        circle.setAttribute('fill', 'currentColor');
                        circle.setAttribute('stroke', 'none');
                        svg.appendChild(circle);
                        
                        var stem = document.createElementNS('http://www.w3.org/2000/svg', 'line');
                        stem.setAttribute('x1', '8');
                        stem.setAttribute('y1', '16');
                        stem.setAttribute('x2', '8');
                        stem.setAttribute('y2', '6');
                        svg.appendChild(stem);
                        
                        var flag = document.createElementNS('http://www.w3.org/2000/svg', 'path');
                        flag.setAttribute('d', 'M8 6c3 0 4 1.5 5 3');
                        svg.appendChild(flag);
                        
                        var line1 = document.createElementNS('http://www.w3.org/2000/svg', 'line');
                        line1.setAttribute('x1', '13');
                        line1.setAttribute('y1', '8');
                        line1.setAttribute('x2', '20');
                        line1.setAttribute('y2', '8');
                        svg.appendChild(line1);
                        
                        var line2 = document.createElementNS('http://www.w3.org/2000/svg', 'line');
                        line2.setAttribute('x1', '13');
                        line2.setAttribute('y1', '12');
                        line2.setAttribute('x2', '20');
                        line2.setAttribute('y2', '12');
                        svg.appendChild(line2);
                        
                        var line3 = document.createElementNS('http://www.w3.org/2000/svg', 'line');
                        line3.setAttribute('x1', '13');
                        line3.setAttribute('y1', '16');
                        line3.setAttribute('x2', '18');
                        line3.setAttribute('y2', '16');
                        svg.appendChild(line3);
                        
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
                    } else {
                        // Defensive update: If the button exists but doesn't have the new music note style, replace it with the new SVG design
                        var existingSvg = btn.querySelector('svg');
                        if (existingSvg && !existingSvg.querySelector('circle')) {
                            while (existingSvg.firstChild) {
                                existingSvg.removeChild(existingSvg.firstChild);
                            }
                            existingSvg.setAttribute('fill', 'none');
                            existingSvg.setAttribute('stroke', 'currentColor');
                            existingSvg.setAttribute('stroke-width', '2');
                            existingSvg.setAttribute('stroke-linecap', 'round');
                            existingSvg.setAttribute('stroke-linejoin', 'round');
                            
                            var circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
                            circle.setAttribute('cx', '7');
                            circle.setAttribute('cy', '16');
                            circle.setAttribute('r', '2');
                            circle.setAttribute('fill', 'currentColor');
                            circle.setAttribute('stroke', 'none');
                            existingSvg.appendChild(circle);
                            
                            var stem = document.createElementNS('http://www.w3.org/2000/svg', 'line');
                            stem.setAttribute('x1', '8');
                            stem.setAttribute('y1', '16');
                            stem.setAttribute('x2', '8');
                            stem.setAttribute('y2', '6');
                            existingSvg.appendChild(stem);
                            
                            var flag = document.createElementNS('http://www.w3.org/2000/svg', 'path');
                            flag.setAttribute('d', 'M8 6c3 0 4 1.5 5 3');
                            existingSvg.appendChild(flag);
                            
                            var line1 = document.createElementNS('http://www.w3.org/2000/svg', 'line');
                            line1.setAttribute('x1', '13');
                            line1.setAttribute('y1', '8');
                            line1.setAttribute('x2', '20');
                            line1.setAttribute('y2', '8');
                            existingSvg.appendChild(line1);
                            
                            var line2 = document.createElementNS('http://www.w3.org/2000/svg', 'line');
                            line2.setAttribute('x1', '13');
                            line2.setAttribute('y1', '12');
                            line2.setAttribute('x2', '20');
                            line2.setAttribute('y2', '12');
                            existingSvg.appendChild(line2);
                            
                            var line3 = document.createElementNS('http://www.w3.org/2000/svg', 'line');
                            line3.setAttribute('x1', '13');
                            line3.setAttribute('y1', '16');
                            line3.setAttribute('x2', '18');
                            line3.setAttribute('y2', '16');
                            existingSvg.appendChild(line3);
                        }
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
                
                // 1. Primary: Extract directly from DOM elements (reflects visual Chinese text on screen)
                var titleEl = root.querySelector('.title') || document.querySelector('ytmusic-player-bar .title');
                var bylineEl = root.querySelector('.byline') || document.querySelector('ytmusic-player-bar .byline') || root.querySelector('.subtitle');
                
                if (titleEl) title = titleEl.textContent.trim();
                
                if (bylineEl) {
                    // Extract strictly the artist name from the byline
                    var links = bylineEl.querySelectorAll('a');
                    var artistParts = [];
                    var detectedAlbum = "";
                    for (var i = 0; i < links.length; i++) {
                        var href = links[i].getAttribute('href') || "";
                        var text = links[i].textContent.trim();
                        if (text) {
                            if (href.indexOf('browse/MPRE') !== -1 || href.indexOf('album/') !== -1) {
                                detectedAlbum = text;
                            } else if (href.indexOf('channel/') !== -1 || href.indexOf('browse/UC') !== -1 || href.indexOf('browse/FIBY') !== -1 || href.indexOf('browse/FE') !== -1 || (href.indexOf('browse/') !== -1 && href.indexOf('browse/MPRE') === -1)) {
                                artistParts.push(text);
                            }
                        }
                    }
                    if (artistParts.length > 0) {
                        artist = artistParts.join(' & ');
                    } else {
                        // Fallback: split by any bullet/middle dot characters
                        var parts = bylineEl.textContent.split(/\\s*[\\u2022\\u00b7•·]\\s*/);
                        if (parts.length > 0) {
                            artist = parts[0].trim();
                        }
                    }
                    if (!artist) {
                        artist = bylineEl.textContent.trim();
                    }
                    if (detectedAlbum) {
                        album = detectedAlbum;
                    }
                }
                
                var albumArtImg = root.querySelector('img.image') || root.querySelector('.image') || document.querySelector('ytmusic-player-bar img.image') || root.querySelector('#thumbnail img');
                if (albumArtImg) albumArt = albumArtImg.src;
                
                // Prioritize high-resolution MediaSession artwork if available
                if (navigator.mediaSession && navigator.mediaSession.metadata && navigator.mediaSession.metadata.artwork && navigator.mediaSession.metadata.artwork.length > 0) {
                    var artwork = navigator.mediaSession.metadata.artwork;
                    var mediaArt = artwork[artwork.length - 1].src || "";
                    if (mediaArt) albumArt = mediaArt;
                }
                
                // Boost resolution of albumArt image to get premium high-fidelity 1000x1000 artwork
                if (albumArt) {
                    albumArt = albumArt.replace(/=w\\d+-h\\d+/, "=w1000-h1000")
                                       .replace(/=s\\d+/, "=s1000")
                                       .replace(/\\/s\\d+-c\\//, "/s1000-c/");
                }
                
                // 2. Secondary Fallback: If DOM is empty, fallback to MediaSession API
                if (!title || !artist) {
                    if (navigator.mediaSession && navigator.mediaSession.metadata) {
                        title = navigator.mediaSession.metadata.title || "";
                        artist = navigator.mediaSession.metadata.artist || "";
                        album = navigator.mediaSession.metadata.album || "";
                        if (navigator.mediaSession.metadata.artwork && navigator.mediaSession.metadata.artwork.length > 0) {
                            var artwork = navigator.mediaSession.metadata.artwork;
                            var fallbackArt = artwork[artwork.length - 1].src || "";
                            if (fallbackArt) {
                                albumArt = fallbackArt.replace(/=w\\d+-h\\d+/, "=w1000-h1000")
                                                      .replace(/=s\\d+/, "=s1000")
                                                      .replace(/\\/s\\d+-c\\//, "/s1000-c/");
                            }
                        }
                    }
                }
                
                // 3. Robust triple-fallback for album
                if (!album) {
                    var byline = root.querySelector('.byline') || document.querySelector('ytmusic-player-bar .byline');
                    if (byline) {
                        var links = byline.querySelectorAll('a');
                        for (var i = 0; i < links.length; i++) {
                            var href = links[i].getAttribute('href') || "";
                            if (href.indexOf('browse/MPRE') !== -1 || href.indexOf('album/') !== -1) {
                                album = links[i].textContent.trim();
                                break;
                            }
                        }
                        if (!album) {
                            var parts = byline.textContent.split(/\\s*[\\u2022\\u00b7•·]\\s*/);
                            if (parts.length >= 2) {
                                var secondPart = parts[1].trim();
                                if (/^\\d{4}$/.test(secondPart)) {
                                    album = "";
                                } else {
                                    album = secondPart;
                                }
                            }
                        }
                    }
                }
                
                if (!album && navigator.mediaSession && navigator.mediaSession.metadata) {
                    album = navigator.mediaSession.metadata.album || "";
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
                
                console.log("[Bridge Send] title: " + title + ", artist: " + artist + ", album: " + album);
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

        // Intercept double-clicks anywhere in the viewport to toggle/exit Mini Player mode
        document.addEventListener('dblclick', function(e) {
            if (document.documentElement.classList.contains('mini-player-active')) {
                e.preventDefault();
                e.stopPropagation();
                window.webkit.messageHandlers.YTMBridge.postMessage({
                    event: "toggleMiniPlayer"
                });
            }
        });

        // Intercept clicks on the web player expand buttons in Mini Player mode to exit natively
        document.addEventListener('click', function(e) {
            if (document.documentElement.classList.contains('mini-player-active')) {
                var expandBtn = e.target.closest('.expand-button') || e.target.closest('#expand-button');
                if (expandBtn) {
                    e.preventDefault();
                    e.stopPropagation();
                    window.webkit.messageHandlers.YTMBridge.postMessage({
                        event: "toggleMiniPlayer"
                    });
                }
            }
        }, true);
        """
        let monitorScript = WKUserScript(source: jsMonitor, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(monitorScript)
        
        let jsLangMock = """
        (function() {
            try {
                var getCookieLang = function() {
                    var match = document.cookie.match(/(?:^|; )PREF=([^;]+)/);
                    if (match) {
                        var pref = match[1];
                        var hlMatch = pref.match(/hl=([^&]+)/);
                        if (hlMatch) return hlMatch[1];
                    }
                    var urlMatch = window.location.search.match(/[?&]hl=([^&]+)/);
                    if (urlMatch) return urlMatch[1];
                    return 'zh-CN';
                };
                var activeLang = getCookieLang();
                Object.defineProperty(navigator, 'language', {
                    get: function() { return activeLang; },
                    configurable: true
                });
                Object.defineProperty(navigator, 'languages', {
                    get: function() { return [activeLang, activeLang.split('-')[0]]; },
                    configurable: true
                });
            } catch (e) {
                console.error('Failed to mock navigator.language:', e);
            }
        })();
        """
        let langScript = WKUserScript(source: jsLangMock, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(langScript)
        
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
        
        // Determine initial language code dynamically
        let langCode = getActiveLanguageCode()
        
        // Register observer for dynamic language changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LanguageChanged"),
            object: nil,
            queue: .main
        ) { _ in
            let newLang = getActiveLanguageCode()
            applyLanguageCookie(to: webView, langCode: newLang) {
                DispatchQueue.main.async {
                    if let newUrl = URL(string: "https://music.youtube.com/?hl=\(newLang)") {
                        var req = URLRequest(url: newUrl)
                        req.setValue("\(newLang),zh;q=0.9,en-US;q=0.8,en;q=0.7", forHTTPHeaderField: "Accept-Language")
                        webView.load(req)
                    }
                }
            }
        }
        
        // Load initial page after configuring language cookie to ensure flawless first-frame rendering
        applyLanguageCookie(to: webView, langCode: langCode) {
            DispatchQueue.main.async {
                if let localizedUrl = URL(string: "https://music.youtube.com/?hl=\(langCode)") {
                    var request = URLRequest(url: localizedUrl)
                    request.setValue("\(langCode),zh;q=0.9,en-US;q=0.8,en;q=0.7", forHTTPHeaderField: "Accept-Language")
                    webView.load(request)
                }
            }
        }
        
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
        
        // Register observer to toggle the web player page (Now Playing)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ToggleWebPlayerPage"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔔 Swift: Received ToggleWebPlayerPage notification! Injecting JavaScript...")
            let js = """
            (function() {
                var playerBar = document.querySelector('ytmusic-player-bar');
                if (playerBar) {
                    // Save original styles
                    var prevStyle = playerBar.getAttribute('style') || '';
                    
                    // Temporarily force playerBar and background to be visible & interactable in layout
                    playerBar.style.setProperty('position', 'fixed', 'important');
                    playerBar.style.setProperty('bottom', '0px', 'important');
                    playerBar.style.setProperty('height', '72px', 'important');
                    playerBar.style.setProperty('width', '100vw', 'important');
                    playerBar.style.setProperty('opacity', '1', 'important');
                    playerBar.style.setProperty('visibility', 'visible', 'important');
                    playerBar.style.setProperty('overflow', 'visible', 'important');
                    playerBar.style.setProperty('display', 'flex', 'important');
                    playerBar.style.setProperty('pointer-events', 'auto', 'important');
                    
                    var pbBg = document.querySelector('#player-bar-background');
                    var prevBgStyle = pbBg ? (pbBg.getAttribute('style') || '') : '';
                    if (pbBg) {
                        pbBg.style.setProperty('position', 'fixed', 'important');
                        pbBg.style.setProperty('bottom', '0px', 'important');
                        pbBg.style.setProperty('height', '72px', 'important');
                        pbBg.style.setProperty('opacity', '1', 'important');
                        pbBg.style.setProperty('visibility', 'visible', 'important');
                    }
                    
                    var layout = document.querySelector('ytmusic-app-layout');
                    var prevLayoutStyle = layout ? (layout.getAttribute('style') || '') : '';
                    if (layout) {
                        layout.style.setProperty('pointer-events', 'auto', 'important');
                    }

                    var root = playerBar.shadowRoot || playerBar;
                    var expandBtn = root.querySelector('.expand-button') || root.querySelector('#expand-button') || root.querySelector('ytmusic-player-bar .expand-button');
                    
                    var safeClick = function(el) {
                        if (!el) return false;
                        
                        var mousedown = new MouseEvent('mousedown', {
                            bubbles: true,
                            cancelable: true,
                            composed: true,
                            clientX: window.innerWidth / 2,
                            clientY: window.innerHeight - 36
                        });
                        var mouseup = new MouseEvent('mouseup', {
                            bubbles: true,
                            cancelable: true,
                            composed: true,
                            clientX: window.innerWidth / 2,
                            clientY: window.innerHeight - 36
                        });
                        var click = new MouseEvent('click', {
                            bubbles: true,
                            cancelable: true,
                            composed: true,
                            clientX: window.innerWidth / 2,
                            clientY: window.innerHeight - 36
                        });
                        
                        el.dispatchEvent(mousedown);
                        el.dispatchEvent(mouseup);
                        el.dispatchEvent(click);
                        
                        if (typeof el.click === 'function') {
                            el.click();
                        }
                        return true;
                    };
                    
                    var clicked = false;
                    if (expandBtn) {
                        clicked = safeClick(expandBtn);
                    }
                    if (!clicked) {
                        var leftContent = root.querySelector('.left-content') || root.querySelector('#thumbnail');
                        if (leftContent) {
                            clicked = safeClick(leftContent);
                        }
                    }
                    if (!clicked) {
                        clicked = safeClick(playerBar);
                    }
                    
                    // Restore original styles after a minor delay
                    setTimeout(function() {
                        if (prevStyle) {
                            playerBar.setAttribute('style', prevStyle);
                        } else {
                            playerBar.removeAttribute('style');
                        }
                        
                        if (pbBg) {
                            if (prevBgStyle) {
                                pbBg.setAttribute('style', prevBgStyle);
                            } else {
                                pbBg.removeAttribute('style');
                            }
                        }
                        
                        if (layout) {
                            if (prevLayoutStyle) {
                                layout.setAttribute('style', prevLayoutStyle);
                            } else {
                                layout.removeAttribute('style');
                            }
                        }
                    }, 50);
                    
                    return clicked;
                }
                return false;
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
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
                } else if event == "toggleMiniPlayer" {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("ToggleMiniPlayer"), object: nil)
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

fileprivate func getActiveLanguageCode() -> String {
    let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "auto"
    if saved == "auto" {
        let systemLang = Locale.preferredLanguages.first ?? "zh-CN"
        return systemLang.hasPrefix("zh") ? "zh-CN" : "en"
    }
    return saved
}

fileprivate func applyLanguageCookie(to webView: WKWebView, langCode: String, completion: @escaping () -> Void) {
    let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
    cookieStore.getAllCookies { cookies in
        var prefValue = "hl=\(langCode)"
        if let prefCookie = cookies.first(where: { $0.name == "PREF" }) {
            var dict: [String: String] = [:]
            let parts = prefCookie.value.split(separator: "&")
            for part in parts {
                let kv = part.split(separator: "=")
                if kv.count == 2 {
                    dict[String(kv[0])] = String(kv[1])
                }
            }
            dict["hl"] = langCode
            prefValue = dict.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        }
        
        let domains = [".youtube.com", ".music.youtube.com", "music.youtube.com"]
        let group = DispatchGroup()
        
        for domain in domains {
            group.enter()
            let cookieProperties: [HTTPCookiePropertyKey: Any] = [
                .name: "PREF",
                .value: prefValue,
                .domain: domain,
                .path: "/",
                .expires: Date(timeIntervalSinceNow: 31536000) // 1 year
            ]
            
            if let newCookie = HTTPCookie(properties: cookieProperties) {
                DispatchQueue.main.async {
                    cookieStore.setCookie(newCookie) {
                        print("✓ Cookie PREF set to \(prefValue) on \(domain)")
                        group.leave()
                    }
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion()
        }
    }
}
