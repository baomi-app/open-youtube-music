import Foundation
import MediaPlayer
import AppKit
import UserNotifications

class NowPlayingManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NowPlayingManager()
    
    private var lastTitle = ""
    private var lastArtist = ""
    private var currentAlbumArtUrl = ""
    private var notificationWorkItem: DispatchWorkItem?
    
    func start() {
        setupRemoteCommands()
        
        // Request authorization and set delegate for modern UserNotifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
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
        
        // Trigger a macOS system notification when a new song starts playing
        let isNewTrack = title != lastTitle || artist != lastArtist
        if isNewTrack && playing && !title.isEmpty {
            lastTitle = title
            lastArtist = artist
            
            // Cancel any pending notification to prevent duplicates or race conditions
            notificationWorkItem?.cancel()
            
            // Delay notification slightly (600ms) to allow the album artwork URL to catch up.
            // When transitioning tracks, title/artist update instantly in DOM/MediaSession,
            // but the artwork URL takes a split second to load.
            let titleToShow = title
            let artistToShow = artist
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.showNotification(title: titleToShow, subtitle: artistToShow, artworkUrl: self.currentAlbumArtUrl)
            }
            notificationWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
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
    
    private func saveArtworkToTempFile(from urlString: String, completion: @escaping (URL?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else {
                completion(nil)
                return
            }
            
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
            
            do {
                try data.write(to: tempFileURL)
                completion(tempFileURL)
            } catch {
                print("Failed to write artwork data to temp file: \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    private func showNotification(title: String, subtitle: String, artworkUrl: String?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        
        if let artworkUrl = artworkUrl, !artworkUrl.isEmpty {
            saveArtworkToTempFile(from: artworkUrl) { [weak self] tempURL in
                guard let self = self else { return }
                
                if let tempURL = tempURL {
                    do {
                        let attachment = try UNNotificationAttachment(
                            identifier: UUID().uuidString,
                            url: tempURL,
                            options: nil
                        )
                        content.attachments = [attachment]
                    } catch {
                        print("Error creating notification attachment: \(error)")
                    }
                }
                
                // Deliver notification and pass tempURL to clean up afterwards
                self.deliverNotification(content: content, tempURL: tempURL)
            }
        } else {
            deliverNotification(content: content, tempURL: nil)
        }
    }
    
    private func deliverNotification(content: UNNotificationContent, tempURL: URL?) {
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error delivering notification: \(error)")
            }
            
            // Safe cleanup of temporary artwork file on completion
            if let tempURL = tempURL {
                do {
                    try FileManager.default.removeItem(at: tempURL)
                } catch {
                    print("Error removing temporary artwork file: \(error)")
                }
            }
        }
    }
    
    // Enable foreground notifications (crucial for user testing & instant feedback)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .list])
        } else {
            completionHandler([.alert])
        }
    }
}
