import SwiftUI

struct SidebarLyricsView: View {
    @ObservedObject var state = AppState.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Lyrics")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
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
            .padding(.top, 50) // Space for macOS window titlebar/traffic lights
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            if state.lyricLines.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.2))
                        .padding(.bottom, 12)
                    Text(state.lyricsLoading ? "Fetching lyrics..." : "No synced lyrics available")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
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
                                    .shadow(color: isActive ? .red.opacity(0.5) : .clear, radius: isActive ? 8 : 0)
                                    .scaleEffect(isActive ? 1.05 : 0.95)
                                    .blur(radius: isActive ? 0 : 0.4)
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
                Text("🎵 Open YouTube Music")
                    .font(.system(size: CGFloat(20 * state.lyricsScale), weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                let activeIndex = state.activeLyricIndex ?? -1
                
                // Line 1: Active Lyric (single line, no ellipsis, no shadow)
                let activeText = (activeIndex >= 0 && activeIndex < state.lyricLines.count)
                    ? state.lyricLines[activeIndex].text
                    : "Music playing..."
                
                Text(activeText)
                    .font(.system(size: CGFloat(36 * state.lyricsScale), weight: .black)) // Bold and highly readable font size
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1) // Keep strictly on a single line!
                    .fixedSize(horizontal: true, vertical: false) // Unconstrained horizontal bounds for natural size measurement!
                    .animation(.easeInOut(duration: 0.25), value: activeText)
                
                // Line 2: Next Lyric (single line, no ellipsis, no shadow, no blur, dynamic scaling)
                let nextIndex = activeIndex + 1
                let nextText = (nextIndex >= 0 && nextIndex < state.lyricLines.count)
                    ? state.lyricLines[nextIndex].text
                    : ""
                
                if !nextText.isEmpty {
                    Text(nextText)
                        .font(.system(size: CGFloat(24 * state.lyricsScale), weight: .bold)) // High readability secondary line
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineLimit(1) // Keep strictly on a single line!
                        .fixedSize(horizontal: true, vertical: false) // Unconstrained horizontal bounds for natural size measurement!
                        .animation(.easeInOut(duration: 0.25), value: nextText)
                }
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.65)) // Sleek transparent capsule background for perfect legibility without shadows
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
            // Left Component: Track Info & Album Art
            HStack(spacing: 12) {
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
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.trackTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: 200, alignment: .leading)
                    
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
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleDesktopLyrics"), object: nil)
                }) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 14))
                        .foregroundColor(state.showDesktopLyrics ? .red : .secondary)
                        .shadow(color: state.showDesktopLyrics ? Color.red.opacity(0.6) : Color.clear, radius: 4)
                }
                .buttonStyle(.plain)
                .help("Toggle Floating Desktop Lyrics")
                
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleSidebarLyrics"), object: nil)
                }) {
                    Image(systemName: "quote.bubble.fill")
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

