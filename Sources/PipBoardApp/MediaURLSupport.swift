import Foundation

extension URL {
    var pipIsPlayableURL: Bool {
        ["http", "https", "file"].contains(scheme?.lowercased())
    }

    var pipIsDirectPlayableMediaURL: Bool {
        pipIsPlayableURL && ["mp4", "m4v", "mov", "m3u8", "mp3", "aac", "m4a"].contains(pathExtension.lowercased())
    }

    var pipIsDownloadableFileURL: Bool {
        pipIsPlayableURL && ["mp4", "m4v", "mov", "mp3", "aac", "m4a"].contains(pathExtension.lowercased())
    }

    var pipBrowserPlaybackURL: URL {
        guard let youtubeID = pipYouTubeVideoID else { return self }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube.com"
        components.path = "/embed/\(youtubeID)"
        components.queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "autoplay", value: "1")
        ]
        return components.url ?? self
    }

    private var pipYouTubeVideoID: String? {
        guard let host = host?.lowercased() else { return nil }
        if host == "youtu.be" {
            return pathComponents.dropFirst().first
        }
        if host == "youtube.com" || host == "www.youtube.com" || host == "m.youtube.com" {
            if path == "/watch",
               let items = URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems,
               let value = items.first(where: { $0.name == "v" })?.value,
               value.isEmpty == false {
                return value
            }
            if pathComponents.count >= 3, ["shorts", "live", "embed"].contains(pathComponents[1]) {
                return pathComponents[2]
            }
        }
        return nil
    }

    var pipInferredMimeType: String? {
        switch pathExtension.lowercased() {
        case "m3u8": return "application/vnd.apple.mpegurl"
        case "mp4", "m4v": return "video/mp4"
        case "mov": return "video/quicktime"
        case "mp3": return "audio/mpeg"
        case "aac": return "audio/aac"
        case "m4a": return "audio/mp4"
        default: return nil
        }
    }
}
