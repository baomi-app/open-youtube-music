import Foundation

struct LyricLine: Identifiable, Equatable, Hashable {
    let id = UUID()
    let time: TimeInterval // in seconds
    let text: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct LyricSearchResult: Identifiable, Equatable, Hashable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String
    let duration: TimeInterval
    let syncedLyrics: String
    var isNetease: Bool = false
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(isNetease)
    }
    
    static func == (lhs: LyricSearchResult, rhs: LyricSearchResult) -> Bool {
        return lhs.id == rhs.id && lhs.isNetease == rhs.isNetease
    }
}

struct LyricCorrectionEntry: Codable {
    let source: String       // "netease" or "lrclib"
    let id: Int             // The unique ID from the lyric source
    let trackName: String   // Selected lyric track name (for debugging/readability)
    let artistName: String  // Selected lyric artist name (for debugging/readability)
    let timestamp: TimeInterval // Unix epoch timestamp
}

class LyricsManager {
    static let shared = LyricsManager()
    
    private var correctionsMap: [String: LyricCorrectionEntry] = [:]
    private let correctionsLock = NSLock()
    
    private var correctionsFileUrl: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Open YouTube Music")
        // Ensure directory exists dynamically
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        return appDir.appendingPathComponent("user_lyrics_map.json")
    }
    
    private init() {
        loadCorrections()
    }
    
    func loadCorrections() {
        correctionsLock.lock()
        defer { correctionsLock.unlock() }
        
        let url = correctionsFileUrl
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            self.correctionsMap = try decoder.decode([String: LyricCorrectionEntry].self, from: data)
            print("✓ Loaded \(self.correctionsMap.count) lyric manual correction memories.")
        } catch {
            print("⚠️ Failed to load lyric corrections: \(error)")
        }
    }
    
    func saveCorrections() {
        correctionsLock.lock()
        defer { correctionsLock.unlock() }
        
        let url = correctionsFileUrl
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self.correctionsMap)
            try data.write(to: url, options: .atomic)
            print("✓ Saved \(self.correctionsMap.count) lyric manual correction memories.")
        } catch {
            print("⚠️ Failed to save lyric corrections: \(error)")
        }
    }
    
    func getCorrection(for key: String) -> LyricCorrectionEntry? {
        correctionsLock.lock()
        defer { correctionsLock.unlock() }
        return correctionsMap[key]
    }
    
    func saveCorrection(for key: String, entry: LyricCorrectionEntry) {
        correctionsLock.lock()
        correctionsMap[key] = entry
        
        // Also save for bilingual split parts if the title contains separators
        let parts = key.components(separatedBy: " - ")
        if parts.count >= 2 {
            let title = parts[0]
            let artist = parts.dropFirst().joined(separator: " - ")
            let titleParts = splitBilingualTitle(title)
            for part in titleParts {
                let partKey = "\(part) - \(artist)"
                if correctionsMap[partKey] == nil {
                    correctionsMap[partKey] = entry
                    print("✓ Saved bilingual alias memory: '\(partKey)' -> \(entry.source):\(entry.id)")
                }
            }
        }
        correctionsLock.unlock()
        
        saveCorrections()
    }
    
    private func setupUserAgent(on request: inout URLRequest) {
        request.setValue("Open-YouTube-Music-macOS/1.0.9 (https://github.com/baomi-app/open-youtube-music; contact@baomi.app)", forHTTPHeaderField: "User-Agent")
    }
    
    // Parses LRC formatted synced lyrics into a sorted array of LyricLines
    func parseLRC(_ lrcText: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let lrcLines = lrcText.components(separatedBy: .newlines)
        
        // Regex pattern to extract minutes, seconds, milliseconds/centiseconds, and text
        // Matches e.g. [01:23.45] Lyric text or [01:23.456] Lyric text
        let regex = try? NSRegularExpression(pattern: "\\[([0-9]+):([0-9]+)[\\.:]([0-9]+)\\](.*)", options: [])
        
        for line in lrcLines {
            let nsString = line as NSString
            let range = NSRange(location: 0, length: nsString.length)
            
            if let match = regex?.firstMatch(in: line, options: [], range: range) {
                if match.numberOfRanges == 5 {
                    let minStr = nsString.substring(with: match.range(at: 1))
                    let secStr = nsString.substring(with: match.range(at: 2))
                    let fracStr = nsString.substring(with: match.range(at: 3))
                    let text = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let min = Double(minStr), let sec = Double(secStr), let frac = Double(fracStr) {
                        // Calculate fraction divisor depending on length (centiseconds vs milliseconds)
                        let divisor = pow(10.0, Double(fracStr.count))
                        let totalSeconds = min * 60.0 + sec + (frac / divisor)
                        
                        // Ignore timestamps that represent empty metadata headers
                        if !text.isEmpty || !lines.contains(where: { $0.time == totalSeconds }) {
                            lines.append(LyricLine(time: totalSeconds, text: text))
                        }
                    }
                }
            }
        }
        
        // Sort lines sequentially
        return lines.sorted(by: { $0.time < $1.time })
    }
    
    // Simplified-to-Traditional Chinese Conversion
    private func toTraditional(_ string: String) -> String {
        let mutableString = NSMutableString(string: string) as CFMutableString
        CFStringTransform(mutableString, nil, "Simplified-Traditional" as CFString, false)
        return mutableString as String
    }
    
    // Traditional-to-Simplified Chinese Conversion
    private func toSimplified(_ string: String) -> String {
        let mutableString = NSMutableString(string: string) as CFMutableString
        CFStringTransform(mutableString, nil, "Traditional-Simplified" as CFString, false)
        return mutableString as String
    }
    
    // Chinese-to-Pinyin Conversion (for robust English name matching)
    private func toPinyin(_ string: String) -> String {
        let mutableString = NSMutableString(string: string) as CFMutableString
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        return (mutableString as String).lowercased()
    }
    
    // Metadata Suffix Cleanups
    func cleanTitle(_ title: String) -> String {
        var cleaned = title
        
        // Remove common YouTube/YTM suffixes, soundtrack, cover, and theme identifiers
        let patterns = [
            "\\s*[\\(（][^\\)）]*(?:Official|Lyric|Video|Audio|Live|Remastered|Version|Track|Edit|Widescreen|feat|with|合作音乐人|合作|伴奏|演奏|remix|prod|主唱|电影|主题曲|片尾曲|插曲|原声带|原声|翻唱|Cover|OST|Soundtrack|Theme|Album)[^\\)）]*[\\)）]",
            "\\s*[\\[［][^\\]］]*(?:Official|Lyric|Video|Audio|Live|Remastered|Version|Track|Edit|Widescreen|feat|with|合作音乐人|合作|伴奏|演奏|remix|prod|主唱|电影|主题曲|片尾曲|插曲|原声带|原声|翻唱|Cover|OST|Soundtrack|Theme|Album)[^\\]］]*[\\]］]",
            "\\s*-\\s*(?:Official|Lyric|Video|Audio|Live|Remastered|Version|Track|Edit|Widescreen|OST|Soundtrack|Theme).*",
            "\\s*-\\s*Afterwards.*" // e.g. 孙燕姿 - 日落 - Afterwards etc.
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: cleaned.utf16.count)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            }
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? title : cleaned
    }
    
    func cleanArtist(_ artist: String) -> String {
        var cleaned = artist
        
        // Split by primary indicators
        let separators = [
            " feat. ", " Feat. ", " & ", " and ", ",", "/", "、", "vs.",
            " • ", " · ", " ‧ ", " - ", " | ",
            "•", "·", "‧"
        ]
        for separator in separators {
            if let first = cleaned.components(separatedBy: separator).first {
                cleaned = first
            }
        }
        
        // Remove trailing English aliases e.g. "孙燕姿 (Stefanie Sun)" -> "孙燕姿"
        if let idx = cleaned.firstIndex(of: "(") {
            cleaned = String(cleaned[..<idx])
        }
        if let idx = cleaned.firstIndex(of: "[") {
            cleaned = String(cleaned[..<idx])
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Split bilingual titles (e.g. "爱情的重量 - The Weight of Love" -> ["爱情的重量", "The Weight of Love"])
    private func splitBilingualTitle(_ title: String) -> [String] {
        var parts: [String] = []
        let separators = [" - ", " / ", " | ", " — "]
        for separator in separators {
            if title.contains(separator) {
                let segments = title.components(separatedBy: separator)
                for seg in segments {
                    let trimmed = seg.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        parts.append(trimmed)
                    }
                }
                break
            }
        }
        return parts
    }
    
    private func tryBilingualParts(parts: [String], index: Int, artist: String, cleanedArtist: String, duration: Int, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        guard index < parts.count else {
            // All bilingual parts failed. Fallback to iTunes translation on the original cleaned title!
            print("🔍 All bilingual parts failed. Falling back to iTunes translation on original title...")
            let cleanOrigTitle = cleanTitle(parts.joined(separator: " - "))
            self.runWaterfallAndITunesTranslation(title: cleanOrigTitle, artist: cleanedArtist, duration: duration, completion: completion)
            return
        }
        
        let partTitle = parts[index]
        print("🔍 Trying bilingual Part \(index + 1)/\(parts.count): Title='\(partTitle)', Artist='\(artist)'")
        
        self.tryPreciseGet(title: partTitle, artist: artist, duration: duration) { [weak self] lines, mTitle, mArtist in
            if let lines = lines {
                completion(lines, mTitle, mArtist)
                return
            }
            
            guard let self = self else { completion(nil, nil, nil); return }
            
            self.tryPreciseGet(title: partTitle, artist: cleanedArtist, duration: duration) { lines, mTitle, mArtist in
                if let lines = lines {
                    completion(lines, mTitle, mArtist)
                    return
                }
                
                self.tryTraditionalAndSimplifiedWaterfall(title: partTitle, artist: cleanedArtist, duration: duration) { lines, mTitle, mArtist in
                    if let lines = lines {
                        completion(lines, mTitle, mArtist)
                        return
                    }
                    
                    self.tryBilingualParts(parts: parts, index: index + 1, artist: artist, cleanedArtist: cleanedArtist, duration: duration, completion: completion)
                }
            }
        }
    }

    // Fetch synced lyrics with Netease Cloud Music priority and resilient LrcLib/iTunes waterfall failover
    func fetchSyncedLyrics(title: String, artist: String, duration: TimeInterval, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        guard !title.isEmpty else {
            completion(nil, nil, nil)
            return
        }

        let cleanedTitle = cleanTitle(title)
        let cleanedArtist = cleanArtist(artist)
        let durationSec = (duration.isNaN || duration.isInfinite) ? 0 : Int(duration)
        let cacheKey = "\(cleanedTitle) - \(cleanedArtist)"

        // 1. Check if a manual lyric correction memory is saved for this song
        if let entry = getCorrection(for: cacheKey) {
            print("✓ Found manual lyric correction memory: \(entry.source):\(entry.id) for '\(cacheKey)'")
            if entry.source == "netease" {
                self.fetchNeteaseLyricsById(songId: entry.id, trackName: entry.trackName, artistName: entry.artistName) { [weak self] lines, mTitle, mArtist in
                    if let lines = lines, !lines.isEmpty {
                        completion(lines, mTitle, mArtist)
                    } else {
                        print("⚠️ Stale netease correction entry \(entry.id) returned empty lyrics. Falling back to default search flow...")
                        guard let self = self else { completion(nil, nil, nil); return }
                        self.executeDefaultFetchFlow(title: title, artist: artist, cleanedTitle: cleanedTitle, cleanedArtist: cleanedArtist, durationSec: durationSec, completion: completion)
                    }
                }
                return
            } else if entry.source == "lrclib" {
                self.fetchLrcLibLyricsById(id: entry.id, trackName: entry.trackName, artistName: entry.artistName) { [weak self] lines, mTitle, mArtist in
                    if let lines = lines, !lines.isEmpty {
                        completion(lines, mTitle, mArtist)
                    } else {
                        print("⚠️ Stale lrclib correction entry \(entry.id) returned empty lyrics. Falling back to default search flow...")
                        guard let self = self else { completion(nil, nil, nil); return }
                        self.executeDefaultFetchFlow(title: title, artist: artist, cleanedTitle: cleanedTitle, cleanedArtist: cleanedArtist, durationSec: durationSec, completion: completion)
                    }
                }
                return
            } else if entry.source == "none" {
                print("✓ Manual correction memory explicitly set to NONE (no lyrics) for '\(cacheKey)'")
                completion([], "No Lyrics", "")
                return
            }
        }

        // 2. No memory found, run the default cascading search flow
        executeDefaultFetchFlow(title: title, artist: artist, cleanedTitle: cleanedTitle, cleanedArtist: cleanedArtist, durationSec: durationSec, completion: completion)
    }

    private func executeDefaultFetchFlow(title: String, artist: String, cleanedTitle: String, cleanedArtist: String, durationSec: Int, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        print("🔍 Syncing lyrics: Querying Netease Cloud Music first...")
        self.tryNeteaseLyrics(title: title, artist: artist, duration: durationSec) { [weak self] lines, mTitle, mArtist in
            if let lines = lines, !lines.isEmpty {
                completion(lines, mTitle, mArtist)
                return
            }

            guard let self = self else {
                completion(nil, nil, nil)
                return
            }

            print("⚠️ Netease returned no synced lyrics. Falling back to LrcLib waterfall flow...")
            self.executeLrcLibWaterfall(title: title, artist: artist, cleanedTitle: cleanedTitle, cleanedArtist: cleanedArtist, durationSec: durationSec, completion: completion)
        }
    }

    private func executeLrcLibWaterfall(title: String, artist: String, cleanedTitle: String, cleanedArtist: String, durationSec: Int, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        // Split bilingual titles (e.g. "爱情的重量 - The Weight of Love")
        let titleParts = splitBilingualTitle(cleanedTitle)
        if !titleParts.isEmpty {
            print("💡 Detected bilingual title, split into: \(titleParts)")
            self.tryBilingualParts(parts: titleParts, index: 0, artist: artist, cleanedArtist: cleanedArtist, duration: durationSec, completion: completion)
            return
        }

        // Step 1: Try precise GET with original metadata
        tryPreciseGet(title: title, artist: artist, duration: durationSec) { [weak self] lines, mTitle, mArtist in
            if let lines = lines {
                completion(lines, mTitle, mArtist)
                return
            }

            // Step 2: Try precise GET with cleaned metadata (if different)
            guard let self = self else { completion(nil, nil, nil); return }
            if cleanedTitle != title || cleanedArtist != artist {
                print("🔍 Step 2: Trying precise GET with cleaned metadata...")
                self.tryPreciseGet(title: cleanedTitle, artist: cleanedArtist, duration: durationSec) { lines, mTitle, mArtist in
                    if let lines = lines {
                        completion(lines, mTitle, mArtist)
                        return
                    }
                    self.runWaterfallAndITunesTranslation(title: cleanedTitle, artist: cleanedArtist, duration: durationSec, completion: completion)
                }
            } else {
                self.runWaterfallAndITunesTranslation(title: cleanedTitle, artist: cleanedArtist, duration: durationSec, completion: completion)
            }
        }
    }

    // Fetch lyrics from Netease Cloud Music with automatic bilingual pairing
    private func tryNeteaseLyrics(title: String, artist: String, duration: Int, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        let cleanT = cleanTitle(title)
        let cleanA = cleanArtist(artist)
        let query = artist.isEmpty ? cleanT : "\(cleanT) \(cleanA)"

        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(nil, nil, nil)
            return
        }

        let urlString = "https://music.163.com/api/search/get/web?s=\(encodedQuery)&type=1&limit=5"
        guard let url = URL(string: urlString) else {
            completion(nil, nil, nil)
            return
        }

        var request = URLRequest(url: url)
        setupUserAgent(on: &request)
        request.timeoutInterval = 5.0

        print("🔍 Netease: Searching for '\(query)'")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                print("✗ Netease: Search request failed or timed out.")
                completion(nil, nil, nil)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let result = json["result"] as? [String: Any],
                   let songs = result["songs"] as? [[String: Any]] {

                    var matchedCandidates: [[String: Any]] = []

                    // Filter candidates based on title/artist matching and duration proximity
                    for song in songs {
                        guard let _ = song["id"] as? Int,
                              let songName = song["name"] as? String else { continue }

                        let candDurationMs = song["duration"] as? Int ?? 0
                        let candDurationSec = candDurationMs / 1000

                        // Check duration proximity (within 15 seconds if we have a valid input duration)
                        if duration > 0 && candDurationSec > 0 {
                            if abs(candDurationSec - duration) > 15 {
                                continue
                            }
                        }

                        // Check title match (case insensitive, ignoring simplified/traditional variance)
                        let lowerTarget = cleanT.lowercased()
                        let tradTarget = self.toTraditional(lowerTarget)
                        let simpTarget = self.toSimplified(lowerTarget)

                        // We also clean the candidate name before comparison to remove extra brackets
                        let cleanedCandName = self.cleanTitle(songName).lowercased()

                        let isTitleMatch = cleanedCandName.contains(lowerTarget) ||
                                           cleanedCandName.contains(tradTarget) ||
                                           cleanedCandName.contains(simpTarget) ||
                                           lowerTarget.contains(cleanedCandName) ||
                                           tradTarget.contains(cleanedCandName) ||
                                           simpTarget.contains(cleanedCandName)

                        if isTitleMatch {
                            matchedCandidates.append(song)
                        }
                    }

                    // If no title match found, but we have search results, use all search results as loose candidates
                    if matchedCandidates.isEmpty {
                        matchedCandidates = songs
                    }

                    self.tryFetchNeteaseLyrics(candidates: matchedCandidates, index: 0, targetArtist: cleanA, targetTitle: cleanT, completion: completion)
                    return
                }
            } catch {
                print("✗ Netease: Failed to parse search JSON: \(error)")
            }
            completion(nil, nil, nil)
        }.resume()
    }

    private func tryFetchNeteaseLyrics(candidates: [[String: Any]], index: Int, targetArtist: String, targetTitle: String, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        guard index < candidates.count else {
            completion(nil, nil, nil)
            return
        }

        let song = candidates[index]
        guard let songId = song["id"] as? Int,
              let trackName = song["name"] as? String else {
            tryFetchNeteaseLyrics(candidates: candidates, index: index + 1, targetArtist: targetArtist, targetTitle: targetTitle, completion: completion)
            return
        }

        let artists = song["artists"] as? [[String: Any]] ?? []
        let artistName = (artists.first?["name"] as? String) ?? targetArtist

        print("🔍 Netease: Attempting candidate \(index + 1)/\(candidates.count): ID \(songId) ('\(trackName)' by '\(artistName)')")
        self.fetchNeteaseLyricsById(songId: songId, trackName: trackName, artistName: artistName) { [weak self] lines, mTitle, mArtist in
            if let lines = lines, !lines.isEmpty {
                completion(lines, mTitle, mArtist)
            } else {
                guard let self = self else { completion(nil, nil, nil); return }
                print("⚠️ Netease: Candidate \(songId) had no synced lyrics. Trying next candidate...")
                self.tryFetchNeteaseLyrics(candidates: candidates, index: index + 1, targetArtist: targetArtist, targetTitle: targetTitle, completion: completion)
            }
        }
    }

    func fetchLrcLibLyricsById(id: Int, trackName: String, artistName: String, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        let urlString = "https://lrclib.net/api/get/\(id)"
        guard let url = URL(string: urlString) else {
            completion(nil, nil, nil)
            return
        }
        
        var request = URLRequest(url: url)
        setupUserAgent(on: &request)
        request.timeoutInterval = 6.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                completion(nil, nil, nil)
                return
            }
            
            if self.checkHTMLBlock(data, from: urlString) {
                completion(nil, nil, nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let syncedLrc = json["syncedLyrics"] as? String {
                    let parsed = self.parseLRC(syncedLrc)
                    if !parsed.isEmpty {
                        print("✓ Success: Synced lyrics loaded from LrcLib by ID \(id)!")
                        completion(parsed, trackName, artistName)
                        return
                    }
                }
            } catch {
                print("✗ Failed to parse LrcLib get by ID response: \(error)")
            }
            completion(nil, nil, nil)
        }.resume()
    }

    func fetchNeteaseLyricsById(songId: Int, trackName: String, artistName: String, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        let urlString = "https://music.163.com/api/song/lyric?os=pc&id=\(songId)&lv=-1&kv=-1&tv=-1"
        guard let url = URL(string: urlString) else {
            completion(nil, nil, nil)
            return
        }

        var request = URLRequest(url: url)
        setupUserAgent(on: &request)
        request.timeoutInterval = 5.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                print("✗ Netease: Failed to fetch lyrics for ID \(songId)")
                completion(nil, nil, nil)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let lrcDict = json["lrc"] as? [String: Any]
                    let lyricText = lrcDict?["lyric"] as? String ?? ""

                    let tlyricDict = json["tlyric"] as? [String: Any]
                    let transText = tlyricDict?["lyric"] as? String ?? ""

                    if lyricText.isEmpty {
                        print("✗ Netease: Synced lyrics are empty for ID \(songId)")
                        completion(nil, nil, nil)
                        return
                    }

                    let baseLines = self.parseLRC(lyricText)
                    if baseLines.isEmpty {
                        completion(nil, nil, nil)
                        return
                    }

                    let transLines = self.parseLRC(transText)
                    if transLines.isEmpty {
                        // Return base lines directly if no translations are present
                        print("✓ Netease: Loaded \(baseLines.count) lines of original lyrics (No translation).")
                        completion(baseLines, trackName, artistName)
                        return
                    }

                    // Merge original lyrics with translated lyrics based on timestamp proximity
                    var mergedLines: [LyricLine] = []
                    for line in baseLines {
                        // Find matching translation line within 0.15s threshold
                        if let matchedTrans = transLines.first(where: { abs($0.time - line.time) < 0.15 }) {
                            let trimmedTrans = matchedTrans.text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedTrans.isEmpty {
                                let combinedText = "\(line.text)\n\(trimmedTrans)"
                                mergedLines.append(LyricLine(time: line.time, text: combinedText))
                            } else {
                                mergedLines.append(line)
                            }
                        } else {
                            mergedLines.append(line)
                        }
                    }

                    print("✓ Netease: Successfully loaded & paired \(mergedLines.count) bilingual lines.")
                    completion(mergedLines, trackName, artistName)
                    return
                }
            } catch {
                print("✗ Netease: Failed to parse lyrics JSON: \(error)")
            }
            completion(nil, nil, nil)
        }.resume()
    }


    private func runWaterfallAndITunesTranslation(title: String, artist: String, duration: Int, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        self.tryTraditionalAndSimplifiedWaterfall(title: title, artist: artist, duration: duration) { [weak self] lines, mTitle, mArtist in
            if let lines = lines {
                completion(lines, mTitle, mArtist)
                return
            }
            
            // Standard waterfall returned nothing. Try iTunes translation fallback!
            guard let self = self else { completion(nil, nil, nil); return }
            print("🔍 Standard waterfall failed. Trying iTunes cross-lingual translation fallback...")
            
            self.tryITunesTranslation(title: title, artist: artist) { resolvedTitle, resolvedArtist in
                guard let resolvedTitle = resolvedTitle, !resolvedTitle.isEmpty,
                      resolvedTitle.lowercased() != title.lowercased() || (resolvedArtist != nil && resolvedArtist!.lowercased() != artist.lowercased()) else {
                    print("✗ iTunes translation found no alternative title or artist.")
                    completion(nil, nil, nil)
                    return
                }
                
                print("✓ iTunes translation resolved: '\(title)' by '\(artist)' -> '\(resolvedTitle)' by '\(resolvedArtist ?? artist)'")
                
                let cleanResolvedTitle = self.cleanTitle(resolvedTitle)
                let cleanResolvedArtist = self.cleanArtist(resolvedArtist ?? artist)
                let cleanOriginalTitle = self.cleanTitle(title)
                
                // Trigger secondary waterfall searches!
                // Option A: Clean original title + Clean resolved artist (e.g. "愛了" by "Julia Peng")
                print("🔍 Triggering secondary waterfall Option A (Original title + Resolved artist): Title='\(cleanOriginalTitle)', Artist='\(cleanResolvedArtist)'")
                self.tryPreciseGet(title: cleanOriginalTitle, artist: cleanResolvedArtist, duration: duration) { lines, mTitle, mArtist in
                    if let lines = lines {
                        completion(lines, mTitle, mArtist)
                        return
                    }
                    
                    self.tryTraditionalAndSimplifiedWaterfall(title: cleanOriginalTitle, artist: cleanResolvedArtist, duration: duration) { lines, mTitle, mArtist in
                        if let lines = lines {
                            completion(lines, mTitle, mArtist)
                            return
                        }
                        
                        // Option B: Clean resolved title + Clean resolved artist (e.g. "Love it" by "Julia Peng")
                        print("🔍 Triggering secondary waterfall Option B (Resolved title + Resolved artist): Title='\(cleanResolvedTitle)', Artist='\(cleanResolvedArtist)'")
                        self.tryPreciseGet(title: cleanResolvedTitle, artist: cleanResolvedArtist, duration: duration) { lines, mTitle, mArtist in
                            if let lines = lines {
                                completion(lines, mTitle, mArtist)
                                return
                            }
                            
                            self.tryTraditionalAndSimplifiedWaterfall(title: cleanResolvedTitle, artist: cleanResolvedArtist, duration: duration, completion: completion)
                        }
                    }
                }
            }
        }
    }

    private func tryITunesTranslation(title: String, artist: String, completion: @escaping (String?, String?) -> Void) {
        let query = "\(title) \(artist)"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://itunes.apple.com/search?term=\(encodedQuery)&media=music&entity=song&limit=1"
        
        guard let url = URL(string: urlString) else {
            completion(nil, nil)
            return
        }
        
        var request = URLRequest(url: url)
        setupUserAgent(on: &request)
        request.timeoutInterval = 4.0 // Fast timeout
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil, nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let first = results.first {
                    let trackName = first["trackName"] as? String
                    let artistName = first["artistName"] as? String
                    completion(trackName, artistName)
                    return
                }
            } catch {
                print("✗ Failed to parse iTunes translation: \(error)")
            }
            completion(nil, nil)
        }.resume()
    }

    // Custom manual search for synced lyrics bypassing strict matching rules with Netease priority
    func fetchSyncedLyricsCustom(query: String, duration: TimeInterval, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        guard !query.isEmpty else {
            completion(nil, nil, nil)
            return
        }
        let durationSec = (duration.isNaN || duration.isInfinite) ? 0 : Int(duration)
        print("🔍 Custom synced lyrics search started: Query='\(query)', Duration=\(durationSec)s")

        self.tryNeteaseLyrics(title: query, artist: "", duration: durationSec) { [weak self] lines, mTitle, mArtist in
            if let lines = lines, !lines.isEmpty {
                completion(lines, mTitle, mArtist)
                return
            }

            guard let self = self else {
                completion(nil, nil, nil)
                return
            }

            print("⚠️ Custom search on Netease returned no lyrics. Falling back to LrcLib...")
            self.tryKeywordSearch(query: query, duration: durationSec, targetArtist: "", targetTitle: "", strictArtistCheck: false, strictTitleCheck: false, completion: completion)
        }
    }

    // Search synced lyrics from both LrcLib and Netease Cloud Music concurrently returning all matching candidates
    func searchSyncedLyrics(query: String, completion: @escaping ([LyricSearchResult]?) -> Void) {
        guard !query.isEmpty else {
            completion(nil)
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var mergedResults: [LyricSearchResult] = []
        let resultsLock = NSLock()
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // 1. Query LrcLib
        dispatchGroup.enter()
        let lrclibUrlString = "https://lrclib.net/api/search?q=\(encodedQuery)"
        if let lrclibUrl = URL(string: lrclibUrlString) {
            var request = URLRequest(url: lrclibUrl)
            setupUserAgent(on: &request)
            request.timeoutInterval = 6.0
            
            URLSession.shared.dataTask(with: request) { data, _, error in
                defer { dispatchGroup.leave() }
                guard let data = data, error == nil else { return }
                if LyricsManager.shared.checkHTMLBlock(data, from: lrclibUrlString) { return }
                
                do {
                    if let jsonResults = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        let filtered = jsonResults.filter { ($0["syncedLyrics"] as? String) != nil }
                        var list: [LyricSearchResult] = []
                        for dict in filtered {
                            if let id = dict["id"] as? Int,
                               let trackName = dict["trackName"] as? String,
                               let artistName = dict["artistName"] as? String,
                               let syncedLrc = dict["syncedLyrics"] as? String {
                                let albumName = dict["albumName"] as? String ?? ""
                                let duration = dict["duration"] as? Double ?? 0.0
                                
                                list.append(LyricSearchResult(
                                    id: id,
                                    trackName: trackName,
                                    artistName: artistName,
                                    albumName: albumName,
                                    duration: duration,
                                    syncedLyrics: syncedLrc,
                                    isNetease: false
                                ))
                            }
                        }
                        resultsLock.lock()
                        mergedResults.append(contentsOf: list)
                        resultsLock.unlock()
                    }
                } catch {
                    print("✗ LrcLib search JSON parse error: \(error)")
                }
            }.resume()
        } else {
            dispatchGroup.leave()
        }
        
        // 2. Query Netease Cloud Music
        dispatchGroup.enter()
        let neteaseUrlString = "https://music.163.com/api/search/get/web?s=\(encodedQuery)&type=1&limit=5"
        if let neteaseUrl = URL(string: neteaseUrlString) {
            var request = URLRequest(url: neteaseUrl)
            setupUserAgent(on: &request)
            request.timeoutInterval = 6.0
            
            URLSession.shared.dataTask(with: request) { data, _, error in
                defer { dispatchGroup.leave() }
                guard let data = data, error == nil else { return }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let result = json["result"] as? [String: Any],
                       let songs = result["songs"] as? [[String: Any]] {
                        
                        var list: [LyricSearchResult] = []
                        for song in songs {
                            guard let songId = song["id"] as? Int,
                                  let songName = song["name"] as? String else { continue }
                            
                            var artistName = ""
                            if let artists = song["artists"] as? [[String: Any]] {
                                let names = artists.compactMap { $0["name"] as? String }
                                artistName = names.joined(separator: " & ")
                            }
                            
                            var albumName = ""
                            if let album = song["album"] as? [String: Any] {
                                albumName = album["name"] as? String ?? ""
                            }
                            
                            let candDurationMs = song["duration"] as? Int ?? 0
                            let candDurationSec = Double(candDurationMs) / 1000.0
                            
                            list.append(LyricSearchResult(
                                id: songId,
                                trackName: songName,
                                artistName: artistName,
                                albumName: albumName,
                                duration: candDurationSec,
                                syncedLyrics: "",
                                isNetease: true
                            ))
                        }
                        resultsLock.lock()
                        mergedResults.append(contentsOf: list)
                        resultsLock.unlock()
                    }
                } catch {
                    print("✗ Netease search JSON parse error: \(error)")
                }
            }.resume()
        } else {
            dispatchGroup.leave()
        }
        
        // 3. Notify completion
        dispatchGroup.notify(queue: .main) {
            print("✓ Combined search found \(mergedResults.count) candidates for Query='\(query)'")
            completion(mergedResults)
        }
    }

    private func tryTraditionalAndSimplifiedWaterfall(title: String, artist: String, duration: Int, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        let tradTitle = toTraditional(title)
        let tradArtist = toTraditional(artist)
        let simpTitle = toSimplified(title)
        let simpArtist = toSimplified(artist)

        // Step 3: Try precise GET with Traditional Chinese
        if tradTitle != title || tradArtist != artist {
            print("🔍 Step 3: Trying precise GET with Traditional Chinese ('\(tradTitle)' by '\(tradArtist)')...")
            self.tryPreciseGet(title: tradTitle, artist: tradArtist, duration: duration) { [weak self] lines, mTitle, mArtist in
                if let lines = lines {
                    completion(lines, mTitle, mArtist)
                    return
                }
                guard let self = self else { completion(nil, nil, nil); return }
                self.trySimplifiedAndKeywordWaterfall(title: title, artist: artist, tradTitle: tradTitle, tradArtist: tradArtist, simpTitle: simpTitle, simpArtist: simpArtist, duration: duration, completion: completion)
            }
        } else {
            self.trySimplifiedAndKeywordWaterfall(title: title, artist: artist, tradTitle: tradTitle, tradArtist: tradArtist, simpTitle: simpTitle, simpArtist: simpArtist, duration: duration, completion: completion)
        }
    }

    private func trySimplifiedAndKeywordWaterfall(title: String, artist: String, tradTitle: String, tradArtist: String, simpTitle: String, simpArtist: String, duration: Int, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        // Step 4: Try precise GET with Simplified Chinese
        if simpTitle != title || simpArtist != artist {
            print("🔍 Step 4: Trying precise GET with Simplified Chinese ('\(simpTitle)' by '\(simpArtist)')...")
            self.tryPreciseGet(title: simpTitle, artist: simpArtist, duration: duration) { [weak self] lines, mTitle, mArtist in
                if let lines = lines {
                    completion(lines, mTitle, mArtist)
                    return
                }
                guard let self = self else { completion(nil, nil, nil); return }
                self.tryKeywordSearches(title: title, artist: artist, tradTitle: tradTitle, tradArtist: tradArtist, simpTitle: simpTitle, simpArtist: simpArtist, duration: duration, completion: completion)
            }
        } else {
            self.tryKeywordSearches(title: title, artist: artist, tradTitle: tradTitle, tradArtist: tradArtist, simpTitle: simpTitle, simpArtist: simpArtist, duration: duration, completion: completion)
        }
    }

    private func tryKeywordSearches(title: String, artist: String, tradTitle: String, tradArtist: String, simpTitle: String, simpArtist: String, duration: Int, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        // Step 5: Try keyword search with Traditional Chinese
        let tradQuery = "\(tradTitle) \(tradArtist)"
        print("🔍 Step 5: Trying keyword search with Traditional query: '\(tradQuery)'")
        self.tryKeywordSearch(query: tradQuery, duration: duration, targetArtist: tradArtist, targetTitle: tradTitle) { [weak self] lines, mTitle, mArtist in
            if let lines = lines {
                completion(lines, mTitle, mArtist)
                return
            }
            
            // Step 6: Try keyword search with Simplified Chinese
            guard let self = self else { completion(nil, nil, nil); return }
            let simpQuery = "\(simpTitle) \(simpArtist)"
            print("🔍 Step 6: Trying keyword search with Simplified query: '\(simpQuery)'")
            self.tryKeywordSearch(query: simpQuery, duration: duration, targetArtist: simpArtist, targetTitle: simpTitle) { lines, mTitle, mArtist in
                if let lines = lines {
                    completion(lines, mTitle, mArtist)
                    return
                }
                
                // Step 7: Try keyword search with Cleaned original query
                let cleanQuery = "\(title) \(artist)"
                print("🔍 Step 7: Trying keyword search with Cleaned query: '\(cleanQuery)'")
                self.tryKeywordSearch(query: cleanQuery, duration: duration, targetArtist: artist, targetTitle: title) { lines, mTitle, mArtist in
                    if let lines = lines {
                        completion(lines, mTitle, mArtist)
                        return
                    }
                    
                    // Step 7.5: Search ONLY song title, but enforce STRICT artist matching (e.g. for cover songs)
                    print("🔍 Step 7.5: Searching by song title ONLY but keeping strict artist matching for cover songs: '\(title)'")
                    self.tryKeywordSearch(query: title, duration: duration, targetArtist: artist, targetTitle: title, strictArtistCheck: true, strictTitleCheck: true) { lines, mTitle, mArtist in
                        if let lines = lines {
                            completion(lines, mTitle, mArtist)
                            return
                        }
                        
                        // Step 8: Last resort: search ONLY song title, and filter (strict title check is enabled to guarantee correctness!)
                        print("🔍 Step 8: Last resort keyword search by song title: '\(title)'")
                        self.tryKeywordSearch(query: title, duration: duration, targetArtist: artist, targetTitle: title, strictArtistCheck: false, strictTitleCheck: true) { lines, mTitle, mArtist in
                            if let lines = lines {
                                completion(lines, mTitle, mArtist)
                            } else {
                                print("✗ No synced lyrics found for track.")
                                completion(nil, nil, nil)
                            }
                        }
                    }
                }
            }
        }
    }

    private func tryPreciseGet(title: String, artist: String, duration: Int, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        var urlString = "https://lrclib.net/api/get?track_name=\(encodedTitle)"
        if !encodedArtist.isEmpty {
            urlString += "&artist_name=\(encodedArtist)"
        }
        if duration > 0 {
            urlString += "&duration=\(duration)"
        }
        
        guard let url = URL(string: urlString) else {
            completion(nil, nil, nil)
            return
        }
        
        var request = URLRequest(url: url)
        setupUserAgent(on: &request)
        request.timeoutInterval = 6.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                completion(nil, nil, nil)
                return
            }
            
            if self.checkHTMLBlock(data, from: urlString) {
                completion(nil, nil, nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                completion(nil, nil, nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let syncedLrc = json["syncedLyrics"] as? String {
                    let parsed = self.parseLRC(syncedLrc)
                    if !parsed.isEmpty {
                        print("✓ Success: Precise lyrics match found!")
                        completion(parsed, title, artist)
                        return
                    }
                }
            } catch {
                print("✗ Failed to parse precise GET response: \(error)")
            }
            completion(nil, nil, nil)
        }.resume()
    }

    private func tryKeywordSearch(query: String, duration: Int, targetArtist: String, targetTitle: String, strictArtistCheck: Bool = true, strictTitleCheck: Bool = true, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://lrclib.net/api/search?q=\(encodedQuery)"
        
        guard let url = URL(string: urlString) else {
            completion(nil, nil, nil)
            return
        }
        
        var request = URLRequest(url: url)
        setupUserAgent(on: &request)
        request.timeoutInterval = 8.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                completion(nil, nil, nil)
                return
            }
            
            if self.checkHTMLBlock(data, from: urlString) {
                completion(nil, nil, nil)
                return
            }
            
            do {
                if let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    // Filter candidates containing syncedLyrics
                    var candidates = results.filter { ($0["syncedLyrics"] as? String) != nil }
                    
                    // Filter by duration proximity if duration is valid (within 15s)
                    if duration > 0 {
                        candidates = candidates.filter { candidate in
                            if let candDuration = candidate["duration"] as? Double {
                                return abs(candDuration - Double(duration)) <= 15.0
                            }
                            return true
                        }
                    }
                    
                    // Filter candidates by artist name if strictArtistCheck is enabled
                    if strictArtistCheck && !targetArtist.isEmpty {
                        let targetLower = targetArtist.lowercased()
                        let targetTrad = self.toTraditional(targetLower)
                        let targetSimp = self.toSimplified(targetLower)
                        let targetPinyin = self.toPinyin(targetLower)
                        
                        candidates = candidates.filter { candidate in
                            guard let candArtist = (candidate["artistName"] as? String)?.lowercased() else { return false }
                            let candPinyin = self.toPinyin(candArtist)
                            
                            // Check direct containment
                            if candArtist.contains(targetLower) ||
                               candArtist.contains(targetTrad) ||
                               candArtist.contains(targetSimp) ||
                               targetLower.contains(candArtist) ||
                               targetTrad.contains(candArtist) ||
                               targetSimp.contains(candArtist) {
                                return true
                            }
                            
                            // Check Pinyin containment or overlap
                            // e.g. target="李荣浩" (pinyin "li rong hao"), cand="Ronghao Li" (pinyin "ronghao li")
                            let targetPinyinClean = targetPinyin.replacingOccurrences(of: " ", with: "")
                            let candPinyinClean = candPinyin.replacingOccurrences(of: " ", with: "")
                            if targetPinyinClean == candPinyinClean ||
                               candPinyinClean.contains(targetPinyinClean) ||
                               targetPinyinClean.contains(candPinyinClean) {
                                return true
                            }
                            
                            // Check word-by-word overlap for name inversions (e.g. "Ronghao Li" vs "Li Ronghao")
                            let targetWords = targetPinyin.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
                            let candWords = candPinyin.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
                            
                            let intersection = Set(targetWords).intersection(Set(candWords))
                            if !intersection.isEmpty && (intersection.count >= 2 || (targetWords.count == 1 || candWords.count == 1)) {
                                return true
                            }
                            
                            // Check for combined first/last name mismatch (e.g. ["ronghao", "li"] vs ["li", "rong", "hao"])
                            // We can check if all characters in Pinyin match after sorting or character intersection
                            let targetChars = Set(targetPinyinClean)
                            let candChars = Set(candPinyinClean)
                            if targetChars == candChars && targetPinyinClean.count == candPinyinClean.count {
                                return true
                            }
                            
                            return false
                        }
                    } else if !targetArtist.isEmpty {
                        // Loose Artist Check: Prevent matching completely unrelated artists (e.g. "The Black Keys" vs "Maggie Chiang")
                        let targetLower = targetArtist.lowercased()
                        let targetTrad = self.toTraditional(targetLower)
                        let targetSimp = self.toSimplified(targetLower)
                        
                        candidates = candidates.filter { candidate in
                            guard let candArtist = (candidate["artistName"] as? String)?.lowercased(), !candArtist.isEmpty else {
                                return true // Allow empty candidate artist as last resort
                            }
                            
                            // 1. Direct containment (case-insensitive)
                            if candArtist.contains(targetLower) ||
                               candArtist.contains(targetTrad) ||
                               candArtist.contains(targetSimp) ||
                               targetLower.contains(candArtist) ||
                               targetTrad.contains(candArtist) ||
                               targetSimp.contains(candArtist) {
                                return true
                            }
                            
                            // 2. Chinese character intersection (if any Chinese characters exist)
                            let targetChinese = targetLower.filter { $0.isChinese }
                            let candChinese = candArtist.filter { $0.isChinese }
                            if !targetChinese.isEmpty && !candChinese.isEmpty {
                                let intersection = Set(targetChinese).intersection(Set(candChinese))
                                if !intersection.isEmpty {
                                    return true
                                }
                            }
                            
                            // 3. English word intersection (for names, excluding common stop words)
                            let targetWords = targetLower.components(separatedBy: CharacterSet.alphanumerics.inverted)
                                .filter { $0.count >= 2 && $0 != "the" && $0 != "and" && $0 != "feat" && $0 != "ft" }
                            let candWords = candArtist.components(separatedBy: CharacterSet.alphanumerics.inverted)
                                .filter { $0.count >= 2 && $0 != "the" && $0 != "and" && $0 != "feat" && $0 != "ft" }
                            
                            let intersection = Set(targetWords).intersection(Set(candWords))
                            if !intersection.isEmpty {
                                return true
                            }
                            
                            return false
                        }
                    }
                    
                    // Filter candidates by track name if strictTitleCheck is enabled
                    if strictTitleCheck && !targetTitle.isEmpty {
                        let targetTitleLower = targetTitle.lowercased()
                        let targetTitleTrad = self.toTraditional(targetTitleLower)
                        let targetTitleSimp = self.toSimplified(targetTitleLower)
                        
                        candidates = candidates.filter { candidate in
                            guard let candTitle = (candidate["trackName"] as? String)?.lowercased() else { return false }
                            
                            // Prevent cross-matching Live/Remix/Acoustic/Demo versions with Studio versions
                            let specialKeywords = ["live", "remix", "acoustic", "demo", "instrumental", "伴奏", "演奏", "remaster"]
                            for keyword in specialKeywords {
                                let targetHas = targetTitleLower.contains(keyword)
                                let candHas = candTitle.contains(keyword)
                                if targetHas != candHas {
                                    return false
                                }
                            }
                            
                            let cleanedCand = self.cleanTitle(candTitle).lowercased()
                            return cleanedCand.contains(targetTitleLower) ||
                                   cleanedCand.contains(targetTitleTrad) ||
                                   cleanedCand.contains(targetTitleSimp) ||
                                   targetTitleLower.contains(cleanedCand) ||
                                   targetTitleTrad.contains(cleanedCand) ||
                                   targetTitleSimp.contains(cleanedCand)
                        }
                    }
                    
                    if let firstMatch = candidates.first,
                       let syncedLrc = firstMatch["syncedLyrics"] as? String {
                        let parsed = self.parseLRC(syncedLrc)
                        if !parsed.isEmpty {
                            let matchTitle = firstMatch["trackName"] as? String
                            let matchArtist = firstMatch["artistName"] as? String
                            print("✓ Success: Synced lyrics found via keyword search fallback ('\(matchTitle ?? "")' by '\(matchArtist ?? "")')")
                            completion(parsed, matchTitle, matchArtist)
                            return
                        }
                    }
                }
            } catch {
                print("✗ Failed to parse search response: \(error)")
            }
            completion(nil, nil, nil)
        }.resume()
    }

    private func checkHTMLBlock(_ data: Data, from urlString: String) -> Bool {
        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed.hasPrefix("<!doctype") || trimmed.hasPrefix("<html") || trimmed.contains("cloudflare") {
                print("⚠️ LrcLib: Request to '\(urlString)' returned HTML instead of JSON (blocked or hijacked).")
                return true
            }
        }
        return false
    }
}

extension Character {
    var isChinese: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
    }
}

