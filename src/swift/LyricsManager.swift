import Foundation

struct LyricLine: Identifiable, Equatable, Hashable {
    let id = UUID()
    let time: TimeInterval // in seconds
    let text: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class LyricsManager {
    static let shared = LyricsManager()
    
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
    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
        
        // Remove common YouTube/YTM suffixes
        let patterns = [
            "\\s*[\\(（][^\\)）]*(?:Official|Lyric|Video|Audio|Live|Remastered|Version|Track|Edit|Widescreen|feat|with|合作音乐人|合作|伴奏|演奏|remix|prod|主唱)[^\\)）]*[\\)）]",
            "\\s*[\\[［][^\\]］]*(?:Official|Lyric|Video|Audio|Live|Remastered|Version|Track|Edit|Widescreen|feat|with|合作音乐人|合作|伴奏|演奏|remix|prod|主唱)[^\\]］]*[\\]］]",
            "\\s*-\\s*(?:Official|Lyric|Video|Audio|Live|Remastered|Version|Track|Edit|Widescreen).*",
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
    
    private func cleanArtist(_ artist: String) -> String {
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

    // Fetch synced lyrics from LrcLib with resilient waterfall search
    func fetchSyncedLyrics(title: String, artist: String, duration: TimeInterval, completion: @escaping ([LyricLine]?, String?, String?) -> Void) {
        guard !title.isEmpty else {
            completion(nil, nil, nil)
            return
        }

        let cleanedTitle = cleanTitle(title)
        let cleanedArtist = cleanArtist(artist)
        let durationSec = (duration.isNaN || duration.isInfinite) ? 0 : Int(duration)

        print("🔍 Syncing lyrics waterfall started: Title='\(title)' -> '\(cleanedTitle)', Artist='\(artist)' -> '\(cleanedArtist)', Duration=\(durationSec)s")

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
                    self.tryTraditionalAndSimplifiedWaterfall(title: cleanedTitle, artist: cleanedArtist, duration: durationSec, completion: completion)
                }
            } else {
                self.tryTraditionalAndSimplifiedWaterfall(title: cleanedTitle, artist: cleanedArtist, duration: durationSec, completion: completion)
            }
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
        request.timeoutInterval = 6.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
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
        request.timeoutInterval = 8.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
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
                    }
                    
                    // Filter candidates by track name if strictTitleCheck is enabled
                    if strictTitleCheck && !targetTitle.isEmpty {
                        let targetTitleLower = targetTitle.lowercased()
                        let targetTitleTrad = self.toTraditional(targetTitleLower)
                        let targetTitleSimp = self.toSimplified(targetTitleLower)
                        
                        candidates = candidates.filter { candidate in
                            guard let candTitle = (candidate["trackName"] as? String)?.lowercased() else { return false }
                            return candTitle.contains(targetTitleLower) ||
                                   candTitle.contains(targetTitleTrad) ||
                                   candTitle.contains(targetTitleSimp) ||
                                   targetTitleLower.contains(candTitle) ||
                                   targetTitleTrad.contains(candTitle) ||
                                   targetTitleSimp.contains(candTitle)
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
}
