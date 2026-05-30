import Foundation
import MediaPlayer
import AppKit

class NowPlayingManager {
    static let shared = NowPlayingManager()
    
    private var lastTitle = ""
    private var lastArtist = ""
    private var currentAlbumArtUrl = ""
    
    func start() {
        setupRemoteCommands()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTrackStateChanged(_:)),
            name: NSNotification.Name("TrackStateChanged"),
            object: nil
        )
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "play-pause")
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "play-pause")
            return .success
        }
        
        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "play-pause")
            return .success
        }
        
        // Next track command
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "next")
            return .success
        }
        
        // Previous track command
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in
            NotificationCenter.default.post(name: NSNotification.Name("MediaCommand"), object: "prev")
            return .success
        }
    }
    
    @objc private func handleTrackStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        let title = userInfo["title"] as? String ?? ""
        let artist = userInfo["artist"] as? String ?? ""
        let albumArt = userInfo["albumArt"] as? String ?? ""
        let playing = userInfo["playing"] as? Bool ?? false
        
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // Async update album art if URL changed
        if albumArt != currentAlbumArtUrl && !albumArt.isEmpty {
            currentAlbumArtUrl = albumArt
            fetchArtwork(from: albumArt) { [weak self] image in
                guard let self = self, self.currentAlbumArtUrl == albumArt, let img = image else { return }
                
                var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in
                    return img
                }
                updatedInfo[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
            }
        }
        
        // Trigger a macOS system notification when a new song starts playing in background
        let isNewTrack = title != lastTitle || artist != lastArtist
        if isNewTrack && playing && !title.isEmpty {
            lastTitle = title
            lastArtist = artist
            
            // Only notify if window is not active/key window
            if let window = NSApplication.shared.windows.first, !window.isKeyWindow {
                showNotification(title: title, subtitle: artist)
            }
        }
    }
    
    private func fetchArtwork(from urlString: String, completion: @escaping (NSImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    private func showNotification(title: String, subtitle: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.subtitle = subtitle
        notification.soundName = nil // Silent to match Electron silent notification
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}
