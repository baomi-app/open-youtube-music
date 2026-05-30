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
    ytmusic-player-page, #player-page,
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

    /* Complete, absolute, nuclear-grade hide for the web bottom player bar (replaced by our premium SwiftUI Native player bar!) */
    ytmusic-player-bar, 
    #player-bar, 
    #player-bar-background,
    ytmusic-app-layout [slot="player-bar"] {
      display: none !important;
      visibility: hidden !important;
      height: 0 !important;
      min-height: 0 !important;
      max-height: 0 !important;
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
      background: #000000 !important;
    }

    /* Hide everything except player controls and artwork in mini-player mode */
    html.mini-player-active ytmusic-nav-bar,
    html.mini-player-active ytmusic-guide-renderer,
    html.mini-player-active #content,
    html.mini-player-active ytmusic-player-page {
      display: none !important;
    }

    /* Reposition player bar to fill the whole screen */
    html.mini-player-active ytmusic-player-bar {
      position: fixed !important;
      top: 0 !important;
      left: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      padding: 16px !important;
      box-sizing: border-box !important;
      display: flex !important;
      flex-direction: column !important;
      justify-content: center !important;
      align-items: center !important;
      background: rgba(10, 10, 10, 0.95) !important;
      border: none !important;
      
      /* Explicit overrides for our nuclear hide rules */
      visibility: visible !important;
      opacity: 1 !important;
      pointer-events: auto !important;
    }

    /* Make progress bar full-width at the bottom */
    html.mini-player-active .slider-container.ytmusic-player-bar {
      position: absolute !important;
      bottom: 0 !important;
      left: 0 !important;
      width: 100% !important;
      padding: 0 !important;
    }

    /* Restructure album art, info and controls inside Mini Player */
    html.mini-player-active ytmusic-player-bar .left-content {
      display: flex !important;
      flex-direction: column !important;
      align-items: center !important;
      text-align: center !important;
      margin-bottom: 12px !important;
    }

    html.mini-player-active ytmusic-player-bar .left-content .image {
      width: 140px !important;
      height: 140px !important;
      border-radius: 12px !important;
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5) !important;
      margin-bottom: 12px !important;
    }

    html.mini-player-active ytmusic-player-bar .middle-content {
      margin: 12px 0 !important;
    }
    """
}
