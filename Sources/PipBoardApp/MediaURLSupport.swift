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
