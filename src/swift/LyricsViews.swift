import SwiftUI

private func formatDuration(_ duration: TimeInterval) -> String {
    let mins = Int(duration) / 60
    let secs = Int(duration) % 60
    return String(format: "%02d:%02d", mins, secs)
}

struct SidebarLyricsView: View {
    @ObservedObject var state = AppState.shared
    @State private var showSearchBar = false
    @State private var searchQuery = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lyrics")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    if !state.matchedTitle.isEmpty {
                        Text("Matched: \(state.matchedTitle) - \(state.matchedArtist)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showSearchBar.toggle()
                        if showSearchBar && searchQuery.isEmpty {
                            searchQuery = state.trackTitle == "Not Playing" ? "" : state.trackTitle
                        }
                    }
                }) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.title3)
                        .foregroundColor(showSearchBar ? .blue : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 4)
                
                Button(action: {
                    AppState.shared.showSidebarLyrics = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            if showSearchBar {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Search song, artist, alias...", text: $searchQuery)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .font(.system(size: 13))
                            .onSubmit {
                                state.triggerSearchList(query: searchQuery)
                            }
                        
                        Button(action: {
                            state.triggerSearchList(query: searchQuery)
                        }) {
                            Text("Search")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            if !state.searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Search Results (\(state.searchResults.count))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Button(action: {
                            withAnimation {
                                state.searchResults = []
                            }
                        }) {
                            Text("Clear")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(state.searchResults) { result in
                                Button(action: {
                                    state.selectSearchResult(result)
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(result.trackName)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Spacer()
                                            Text(formatDuration(result.duration))
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        
                                        HStack {
                                            Text(result.artistName)
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.6))
                                                .lineLimit(1)
                                            if !result.albumName.isEmpty {
                                                Text("•")
                                                    .foregroundColor(.white.opacity(0.3))
                                                    .font(.system(size: 10))
                                                Text(result.albumName)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.white.opacity(0.4))
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .transition(.opacity)
            } else if state.lyricLines.isEmpty {
                VStack {
                    Spacer()
                    if state.lyricsLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                            .padding(.bottom, 12)
                        Text("正在获取歌词...")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.2))
                            .padding(.bottom, 12)
                        Text("暂无同步歌词")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.bottom, 24)
                        
                        VStack(spacing: 12) {
                            Text("手动搜索歌词")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 8) {
                                TextField("搜索歌名、歌手...", text: $searchQuery)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                                    .font(.system(size: 13))
                                    .onSubmit {
                                        state.triggerSearchList(query: searchQuery)
                                    }
                                
                                Button(action: {
                                    state.triggerSearchList(query: searchQuery)
                                }) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.8))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .center, spacing: 28) {
                            // Extra space at the top so first line can center
                            Color.clear.frame(height: 150)
                            
                            ForEach(Array(state.lyricLines.enumerated()), id: \.element.id) { index, line in
                                let isActive = index == state.activeLyricIndex
                                
                                Text(line.text)
                                    .font(.system(size: isActive ? CGFloat(22 * state.lyricsScale) : CGFloat(18 * state.lyricsScale), weight: isActive ? .bold : .medium))
                                    .foregroundColor(isActive ? .white : .white.opacity(0.35))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isActive)
                                    .id(line.id)
                                    .onTapGesture {
                                        // Allow user to click lyric to jump! (Legendary integration!)
                                        NotificationCenter.default.post(name: NSNotification.Name("SeekToTime"), object: line.time)
                                    }
                            }
                            
                            // Extra space at the bottom so last line can center
                            Color.clear.frame(height: 250)
                        }
                    }
                    .onChange(of: state.activeLyricIndex) { newIndex in
                        guard let newIndex = newIndex, newIndex >= 0, newIndex < state.lyricLines.count else { return }
                        let lineId = state.lyricLines[newIndex].id
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            proxy.scrollTo(lineId, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 320)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .opacity(0.95)
        )
        .transition(.move(edge: .trailing))
        .contextMenu {
            Section("Lyrics Font Size") {
                Button(action: { state.lyricsScale = 0.8 }) {
                    HStack {
                        Text("Small (80%)")
                        if state.lyricsScale == 0.8 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: { state.lyricsScale = 1.0 }) {
                    HStack {
                        Text("Normal (100%)")
                        if state.lyricsScale == 1.0 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: { state.lyricsScale = 1.2 }) {
                    HStack {
                        Text("Large (120%)")
                        if state.lyricsScale == 1.2 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: { state.lyricsScale = 1.5 }) {
                    HStack {
                        Text("Extra Large (150%)")
                        if state.lyricsScale == 1.5 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: { state.lyricsScale = 1.8 }) {
                    HStack {
                        Text("Huge (180%)")
                        if state.lyricsScale == 1.8 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            Section("Lyrics Sync Offset") {
                Button(action: { state.lyricsOffset += 0.5 }) {
                    Text("Delay Lyrics (+0.5s)")
                }
                Button(action: { state.lyricsOffset -= 0.5 }) {
                    Text("Advance Lyrics (-0.5s)")
                }
                if state.lyricsOffset != 0.0 {
                    Button(action: { state.lyricsOffset = 0.0 }) {
                        Text("Reset (Current: \(String(format: "%.1fs", state.lyricsOffset)))")
                    }
                }
            }
        }
        .onAppear {
            if searchQuery.isEmpty && state.trackTitle != "Not Playing" {
                searchQuery = state.trackTitle
            }
        }
        .onChange(of: state.trackTitle) { newTitle in
            searchQuery = newTitle == "Not Playing" ? "" : newTitle
            showSearchBar = false
        }
    }
}

// SwiftUI Vibrant Visual Effect Wrapper
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Desktop Lyrics Floating View (QQ Music overlay)
struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct DesktopLyricsView: View {
    @ObservedObject var state = AppState.shared
    
    var body: some View {
        VStack(spacing: 10) {
            if state.lyricLines.isEmpty {
                // Explicitly show search/not found status for lyrics
                let statusText = state.lyricsLoading ? "🎵 正在获取歌词..." : "🎵 暂无同步歌词"
                Text(statusText)
                    .font(.system(size: CGFloat(20 * state.lyricsScale), weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .animation(.easeInOut(duration: 0.25), value: statusText)
            } else {
                let activeIndex = state.activeLyricIndex ?? -1
                let isPrelude = activeIndex < 0
                
                if isPrelude {
                    Text("···")
                        .font(.system(size: CGFloat(36 * state.lyricsScale), weight: .black))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .animation(.easeInOut(duration: 0.25), value: "···")
                } else {
                    // Line 1: Active Lyric
                    let activeText = state.lyricLines[activeIndex].text
                    Text(activeText)
                        .font(.system(size: CGFloat(36 * state.lyricsScale), weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .animation(.easeInOut(duration: 0.25), value: activeText)
                    
                    // Line 2: Next Lyric
                    let nextIndex = activeIndex + 1
                    let nextText = (nextIndex >= 0 && nextIndex < state.lyricLines.count)
                        ? state.lyricLines[nextIndex].text
                        : ""
                    
                    if !nextText.isEmpty {
                        Text(nextText)
                            .font(.system(size: CGFloat(24 * state.lyricsScale), weight: .bold))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .animation(.easeInOut(duration: 0.25), value: nextText)
                    }
                }
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.65)) // Sleek transparent capsule background for perfect legibility
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: WidthPreferenceKey.self, value: geometry.size.width)
            }
        )
        .onPreferenceChange(WidthPreferenceKey.self) { width in
            if width > 0 {
                // Post notification to resize the hosting window frame dynamically!
                NotificationCenter.default.post(name: NSNotification.Name("UpdateDesktopLyricsWindowWidth"), object: Double(width))
            }
        }
        .contextMenu {
            Section("Lyrics Font Size") {
                Button(action: { state.lyricsScale = 0.8 }) {
                    HStack {
                        Text("Small (80%)")
                        if state.lyricsScale == 0.8 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: { state.lyricsScale = 1.0 }) {
                    HStack {
                        Text("Normal (100%)")
                        if state.lyricsScale == 1.0 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: { state.lyricsScale = 1.2 }) {
                    HStack {
                        Text("Large (120%)")
                        if state.lyricsScale == 1.2 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: { state.lyricsScale = 1.5 }) {
                    HStack {
                        Text("Extra Large (150%)")
                        if state.lyricsScale == 1.5 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: { state.lyricsScale = 1.8 }) {
                    HStack {
                        Text("Huge (180%)")
                        if state.lyricsScale == 1.8 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
}

// Premium Native SwiftUI Playback Control Bar (Replacing default web player bar)
struct NativePlayerBarView: View {
    @ObservedObject var state = AppState.shared
    @State private var dragTime: Double = 0.0
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 24) {
            // Left Component: Track Info & Album Art (Click to toggle Web Player Page / Now Playing)
            HStack(spacing: 12) {
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleWebPlayerPage"), object: nil)
                }) {
                    if let url = URL(string: state.trackAlbumArt), !state.trackAlbumArt.isEmpty {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                 .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "music.note")
                                .foregroundColor(.gray)
                                .frame(width: 48, height: 48)
                                .background(Color.white.opacity(0.05))
                        }
                        .frame(width: 48, height: 48)
                        .cornerRadius(6)
                        .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Toggle Now Playing View")
                
                VStack(alignment: .leading, spacing: 3) {
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("ToggleWebPlayerPage"), object: nil)
                    }) {
                        Text(state.trackTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Toggle Now Playing View")
                    
                    HStack(spacing: 4) {
                        Button(action: {
                            NotificationCenter.default.post(name: NSNotification.Name("NavigateToArtist"), object: nil)
                        }) {
                            Text(state.trackArtist)
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }
                        .buttonStyle(HoverLinkButtonStyle())
                        
                        if !state.trackAlbum.isEmpty {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            Button(action: {
                                NotificationCenter.default.post(name: NSNotification.Name("NavigateToAlbum"), object: nil)
                            }) {
                                Text(state.trackAlbum)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                            }
                            .buttonStyle(HoverLinkButtonStyle())
                        }
                    }
                    .frame(maxWidth: 200, alignment: .leading)
                }
            }
            .frame(width: 260, alignment: .leading)
            
            // Middle Component: Playback controls + seek timeline slider
            VStack(spacing: 4) {
                HStack(spacing: 24) {
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "prev")
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "play-pause")
                    }) {
                        Image(systemName: state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "next")
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 8) {
                    Text(formatTime(isDragging ? dragTime : state.currentTime))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { isDragging ? dragTime : state.currentTime },
                            set: { newValue in
                                dragTime = newValue
                            }
                        ),
                        in: 0...max(1, state.duration),
                        onEditingChanged: { editing in
                            isDragging = editing
                            if !editing {
                                NotificationCenter.default.post(name: NSNotification.Name("SeekToTime"), object: dragTime)
                            }
                        }
                    )
                    .accentColor(.red)
                    .controlSize(.mini)
                    
                    Text(formatTime(state.duration))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Right Component: App Lyrics Panels Toggles
            HStack(spacing: 20) {
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleMiniPlayer"), object: nil)
                }) {
                    Image(systemName: "pip")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Enter Mini Player")
                
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleDesktopLyrics"), object: nil)
                }) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 14))
                        .foregroundColor(state.showDesktopLyrics ? .red : .secondary)
                        .shadow(color: state.showDesktopLyrics ? Color.red.opacity(0.6) : Color.clear, radius: 4)
                }
                .buttonStyle(.plain)
                .help("Toggle Floating Desktop Lyrics")
                
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleSidebarLyrics"), object: nil)
                }) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 14))
                        .foregroundColor(state.showSidebarLyrics ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle App Sidebar Lyrics")
            }
            .frame(width: 260, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .frame(height: 68)
        .background(
            Color(red: 18/255, green: 18/255, blue: 18/255)
                .opacity(0.85)
        )
        .overlay(
            VStack {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                Spacer()
            }
        )
    }
    
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite && time >= 0 else { return "0:00" }
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// Premium hoverable button style for links in control bar
struct HoverLinkButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .underline(isHovered, color: .red.opacity(0.8))
            .foregroundColor(isHovered ? .red.opacity(0.9) : .secondary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

// Breathtaking, Premium Pure Native SwiftUI Mini Player View
struct NativeMiniPlayerView: View {
    @ObservedObject var state = AppState.shared
    @State private var dragTime: Double = 0.0
    @State private var isDragging = false
    @State private var showLyricsInMini = false
    
    var body: some View {
        ZStack {
            // Background Layer with native window dragging and double-tap exit
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                Color.black.opacity(0.4)
                DraggableBackgroundView()
            }
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 8) {
                // Top header: Left side is empty for macOS traffic lights, Right side contains control buttons
                HStack {
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showLyricsInMini.toggle()
                            }
                        }) {
                            Image(systemName: showLyricsInMini ? "music.note" : "quote.bubble.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(showLyricsInMini ? .red : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .help(showLyricsInMini ? "Show Album Cover" : "Show Lyrics")
                        
                        Button(action: {
                            NotificationCenter.default.post(name: NSNotification.Name("ToggleMiniPlayer"), object: nil)
                        }) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .help("Exit Mini Player")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                
                if showLyricsInMini {
                    // Mini scrolling lyrics view
                    VStack(spacing: 0) {
                        if state.lyricLines.isEmpty {
                            Spacer()
                            Text(state.lyricsLoading ? "正在获取歌词..." : "暂无歌词")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            Spacer()
                        } else {
                            ScrollViewReader { proxy in
                                ScrollView(.vertical, showsIndicators: false) {
                                    VStack(spacing: 12) {
                                        Color.clear.frame(height: 50)
                                        
                                        ForEach(Array(state.lyricLines.enumerated()), id: \.element.id) { index, line in
                                            let isActive = index == state.activeLyricIndex
                                            
                                            Text(line.text)
                                                .font(.system(size: isActive ? CGFloat(18 * state.lyricsScale) : CGFloat(14 * state.lyricsScale), weight: isActive ? .bold : .medium))
                                                .foregroundColor(isActive ? .white : .white.opacity(0.35))
                                                .multilineTextAlignment(.center)
                                                .padding(.horizontal, 12)
                                                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isActive)
                                                .id(line.id)
                                                .onTapGesture {
                                                    NotificationCenter.default.post(name: NSNotification.Name("SeekToTime"), object: line.time)
                                                }
                                        }
                                        
                                        Color.clear.frame(height: 80)
                                    }
                                }
                                .onChange(of: state.activeLyricIndex) { newIndex in
                                    guard let newIndex = newIndex, newIndex >= 0, newIndex < state.lyricLines.count else { return }
                                    let lineId = state.lyricLines[newIndex].id
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        proxy.scrollTo(lineId, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 170)
                } else {
                    // Album Cover Art view
                    VStack(spacing: 12) {
                        if let url = URL(string: state.trackAlbumArt), !state.trackAlbumArt.isEmpty {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                     .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.2))
                                    .frame(width: 140, height: 140)
                                    .background(Color.white.opacity(0.04))
                            }
                            .frame(width: 140, height: 140)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.6), radius: 12, x: 0, y: 6)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 140, height: 140)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.2))
                                )
                                .shadow(color: Color.black.opacity(0.6), radius: 12, x: 0, y: 6)
                        }
                        
                        // Album Art Subtitle: Active lyric line subtitle! (Incredibly premium!)
                        let activeIndex = state.activeLyricIndex ?? -1
                        let activeText = (activeIndex >= 0 && activeIndex < state.lyricLines.count)
                            ? state.lyricLines[activeIndex].text
                            : (state.trackArtist.isEmpty ? "Open YouTube Music" : state.trackArtist)
                        
                        Text(activeText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(activeText == state.trackArtist ? 0.6 : 0.9))
                            .lineLimit(1)
                            .padding(.horizontal, 20)
                            .animation(.easeInOut(duration: 0.25), value: activeText)
                    }
                    .frame(height: 170)
                }
                
                Spacer(minLength: 0)
                
                // Track details: Song Title
                VStack(spacing: 2) {
                    Text(state.trackTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                    
                    if showLyricsInMini {
                        Text(state.trackArtist)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                // Progress timeline slider (fully seekable/controllable!)
                HStack(spacing: 8) {
                    Text(formatTime(isDragging ? dragTime : state.currentTime))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Slider(
                        value: Binding(
                            get: { isDragging ? dragTime : state.currentTime },
                            set: { newValue in
                                dragTime = newValue
                            }
                        ),
                        in: 0...max(1, state.duration),
                        onEditingChanged: { editing in
                            isDragging = editing
                            if !editing {
                                NotificationCenter.default.post(name: NSNotification.Name("SeekToTime"), object: dragTime)
                            }
                        }
                    )
                    .accentColor(.red)
                    .controlSize(.mini)
                    
                    Text(formatTime(state.duration))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 16)
                
                // Playback Buttons
                HStack(spacing: 28) {
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "prev")
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "play-pause")
                    }) {
                        Image(systemName: state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "next")
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 16)
            }
        }
        .frame(width: 340, height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite && time >= 0 else { return "0:00" }
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// -------------------------------------------------------------
// Draggable Background Component for Frameless macOS Windows
// -------------------------------------------------------------
struct DraggableBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableNSView {
        DraggableNSView()
    }
    
    func updateNSView(_ nsView: DraggableNSView, context: Context) {}
}

class DraggableNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            // Double-tap anywhere on the empty mini-player background to exit back to normal layout
            NotificationCenter.default.post(name: NSNotification.Name("ToggleMiniPlayer"), object: nil)
            return
        }
        if let window = self.window {
            // Drag the frameless floating mini-player window smoothly
            window.performDrag(with: event)
        }
    }
}

