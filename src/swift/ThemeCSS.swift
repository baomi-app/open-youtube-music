struct ThemeCSS {
    static let css = """
    /* Premium macOS Aesthetics for YouTube Music */

    /* Set Native macOS Fonts */
    html, body, input, button, select, textarea, ytd-searchbox, ytmusic-search-box {
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", "Helvetica Neue", Helvetica, Arial, sans-serif !important;
    }

    /* Disable WebKit elastic scroll / rubber-banding globally on html and body */
    html, body {
      overscroll-behavior: none !important;
      overscroll-behavior-x: none !important;
      overscroll-behavior-y: none !important;
    }

    /* Make main windows transparent so macOS Vibrancy shows through */
    html, body, ytmusic-app, ytmusic-app-layout, 
    #background, #content, #main-panel, 
    #browse-page, ytmusic-browse-response,
    #player-bar-background {
      background: transparent !important;
      background-color: transparent !important;
    }

    /* Adjust navigation bar for macOS traffic lights */
    ytmusic-nav-bar {
      padding-left: 80px !important;
      background: rgba(18, 18, 18, 0.2) !important;
      backdrop-filter: blur(20px) !important;
      -webkit-backdrop-filter: blur(20px) !important;
      border-bottom: 1px solid rgba(255, 255, 255, 0.05) !important;
      -webkit-app-region: drag; /* Enable dragging window from the nav bar */
    }

    /* Hide the hamburger guide button in the navigation bar to match native macOS sidebar design */
    ytmusic-nav-bar #guide-button,
    ytmusic-nav-bar ytmusic-guide-button-renderer,
    #guide-button,
    ytmusic-guide-button-renderer,
    [aria-label="Guide"],
    button[aria-label="Guide"] {
      display: none !important;
      visibility: hidden !important;
      width: 0 !important;
      height: 0 !important;
      opacity: 0 !important;
      pointer-events: none !important;
    }

    /* Pull the logo to the left to align beautifully next to the traffic lights */
    ytmusic-nav-bar .left-content {
      padding-left: 0px !important;
    }

    /* Force YouTube Music logo and its inner link to align perfectly vertically */
    ytmusic-logo {
      display: flex !important;
      align-items: center !important;
    }
    ytmusic-logo a {
      display: flex !important;
      align-items: center !important;
      height: 100% !important;
    }

    /* Hide off-screen accessibility skip links that leak under traffic lights */
    ytmusic-app [href="#content"],
    .skip-link,
    #skip-to-content,
    .skip-to-content {
      position: absolute !important;
      top: -100px !important;
      left: -9999px !important;
      display: none !important;
    }

    /* Disable drag on interactive navigation elements */
    ytmusic-nav-bar * {
      -webkit-app-region: no-drag;
    }

    /* Glassmorphism Sidebar */
    ytmusic-guide-renderer {
      background: rgba(20, 20, 20, 0.35) !important;
      backdrop-filter: blur(30px) !important;
      -webkit-backdrop-filter: blur(30px) !important;
      border-right: 1px solid rgba(255, 255, 255, 0.05) !important;
    }

    /* Make sidebar entries look cleaner */
    ytmusic-guide-entry-renderer[active] {
      background-color: rgba(255, 255, 255, 0.08) !important;
      border-radius: 8px !important;
    }

    /* Complete hide for the web bottom player bar (replaced by our premium SwiftUI Native player bar!) */
    ytmusic-player-bar, 
    #player-bar, 
    #player-bar-background,
    ytmusic-app-layout [slot="player-bar"] {
      visibility: hidden !important;
      opacity: 0 !important;
      pointer-events: none !important;
    }

    /* Sleek custom macOS-style scrollbars */
    ::-webkit-scrollbar {
      width: 8px;
      height: 8px;
    }

    ::-webkit-scrollbar-track {
      background: transparent !important;
    }

    ::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.12) !important;
      border-radius: 10px !important;
    }

    ::-webkit-scrollbar-thumb:hover {
      background: rgba(255, 255, 255, 0.22) !important;
    }

    /* -------------------------------------------------------------
       Mini Player Layout Rules
       ------------------------------------------------------------- */
    html.mini-player-active body {
      overflow: hidden !important;
    }

    /* Hide everything except player controls and artwork in mini-player mode */
    html.mini-player-active ytmusic-nav-bar,
    html.mini-player-active ytmusic-guide-renderer,
    html.mini-player-active #content,
    html.mini-player-active ytmusic-player-page {
      visibility: hidden !important;
      opacity: 0 !important;
      pointer-events: none !important;
      height: 0 !important;
      overflow: hidden !important;
    }

    /* Force the player bar container slot and elements to be visible */
    html.mini-player-active ytmusic-app-layout [slot="player-bar"],
    html.mini-player-active #player-bar,
    html.mini-player-active #player-bar-background {
      display: block !important;
      visibility: visible !important;
      height: 100vh !important;
      min-height: 100vh !important;
      max-height: 100vh !important;
      opacity: 1 !important;
      pointer-events: auto !important;
    }

    /* Reposition player bar to fill the whole screen */
    html.mini-player-active ytmusic-player-bar {
      position: fixed !important;
      top: 0 !important;
      left: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      padding: 24px 16px !important;
      box-sizing: border-box !important;
      display: flex !important; /* Override nuclear display: none */
      height: 100vh !important; /* Override nuclear height: 0 */
      min-height: 100vh !important;
      max-height: 100vh !important;
      flex-direction: column !important;
      justify-content: space-between !important;
      align-items: center !important;
      background: rgba(10, 10, 10, 0.98) !important;
      border: none !important;
      
      /* Explicit overrides for our nuclear hide rules */
      visibility: visible !important;
      opacity: 1 !important;
      pointer-events: auto !important;
    }

    /* Style the content blocks to stack vertically and center */
    html.mini-player-active ytmusic-player-bar .left-content,
    html.mini-player-active ytmusic-player-bar .middle-content,
    html.mini-player-active ytmusic-player-bar .right-content {
      display: flex !important;
      flex-direction: column !important;
      align-items: center !important;
      justify-content: center !important;
      width: 100% !important;
      margin: 0 !important;
      padding: 0 !important;
      background: transparent !important;
    }

    /* Left Content (Album Art + Title + Artist) */
    html.mini-player-active ytmusic-player-bar .left-content {
      flex: 1 !important;
      justify-content: center !important;
    }

    /* Album Art container and image */
    html.mini-player-active ytmusic-player-bar .left-content #thumbnail,
    html.mini-player-active ytmusic-player-bar .left-content .thumbnail,
    html.mini-player-active ytmusic-player-bar .left-content ytmusic-image-overlay,
    html.mini-player-active ytmusic-player-bar .left-content .image,
    html.mini-player-active ytmusic-player-bar .left-content img {
      width: 160px !important;
      height: 160px !important;
      min-width: 160px !important;
      min-height: 160px !important;
      max-width: 160px !important;
      max-height: 160px !important;
      border-radius: 14px !important;
      overflow: hidden !important;
      box-shadow: 0 12px 36px rgba(0, 0, 0, 0.6) !important;
      margin: 0 auto 16px auto !important;
      display: block !important;
      visibility: visible !important;
      opacity: 1 !important;
    }

    html.mini-player-active ytmusic-player-bar .left-content img {
      object-fit: cover !important;
    }

    /* Track Info (Title and Byline) */
    html.mini-player-active ytmusic-player-bar .left-content .title-mask,
    html.mini-player-active ytmusic-player-bar .left-content .byline {
      max-width: 280px !important;
      overflow: hidden !important;
      text-overflow: ellipsis !important;
      white-space: nowrap !important;
      text-align: center !important;
    }

    html.mini-player-active ytmusic-player-bar .left-content .title {
      font-size: 16px !important;
      font-weight: 700 !important;
      color: #ffffff !important;
      margin-bottom: 4px !important;
      text-align: center !important;
    }

    html.mini-player-active ytmusic-player-bar .left-content .byline {
      font-size: 13px !important;
      color: rgba(255, 255, 255, 0.6) !important;
      text-align: center !important;
    }

    /* Middle Content (Playback Controls) */
    html.mini-player-active ytmusic-player-bar .middle-content {
      flex-direction: row !important;
      justify-content: center !important;
      margin-top: 12px !important;
      margin-bottom: 12px !important;
    }

    html.mini-player-active ytmusic-player-bar .middle-content .playback-buttons {
      display: flex !important;
      flex-direction: row !important;
      align-items: center !important;
      justify-content: center !important;
    }

    /* Style individual control buttons */
    html.mini-player-active ytmusic-player-bar .middle-content tp-yt-paper-icon-button,
    html.mini-player-active ytmusic-player-bar .middle-content yt-icon-button {
      margin: 0 12px !important;
      color: #ffffff !important;
      opacity: 0.8 !important;
      transition: all 0.2s ease !important;
    }

    html.mini-player-active ytmusic-player-bar .middle-content tp-yt-paper-icon-button:hover,
    html.mini-player-active ytmusic-player-bar .middle-content yt-icon-button:hover {
      opacity: 1 !important;
      transform: scale(1.1) !important;
    }

    /* Highlight Play/Pause button in circular background */
    html.mini-player-active ytmusic-player-bar #play-pause-button {
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

    /* Right Content (Hide everything except expand/close button) */
    html.mini-player-active ytmusic-player-bar .right-content {
      position: absolute !important;
      top: 12px !important;
      right: 12px !important;
      width: auto !important;
      flex-direction: row !important;
      z-index: 100 !important;
    }

    html.mini-player-active ytmusic-player-bar .right-content > *:not(.expand-button):not(#expand-button) {
      display: none !important;
    }

    /* Style exit button */
    html.mini-player-active ytmusic-player-bar .right-content .expand-button,
    html.mini-player-active ytmusic-player-bar .right-content #expand-button {
      display: inline-flex !important;
      color: #ffffff !important;
      opacity: 0.6 !important;
      cursor: pointer !important;
      transition: opacity 0.2s ease !important;
    }

    html.mini-player-active ytmusic-player-bar .right-content .expand-button:hover,
    html.mini-player-active ytmusic-player-bar .right-content #expand-button:hover {
      opacity: 1 !important;
    }

    /* Slim, beautiful progress slider at the very bottom */
    html.mini-player-active ytmusic-player-bar #progress-bar,
    html.mini-player-active ytmusic-player-bar tp-yt-paper-slider,
    html.mini-player-active ytmusic-player-bar .slider-container.ytmusic-player-bar {
      position: absolute !important;
      bottom: 0 !important;
      left: 0 !important;
      width: 100% !important;
      height: 4px !important;
      padding: 0 !important;
      margin: 0 !important;
    }
    """
}
