import Foundation

enum ResolveState: Equatable {
    case idle
    case resolving
    case resolved
    case failed(String)
}

struct ResolvedStream: Codable, Identifiable, Equatable {
    let id: String
    let title: String?
    let url: URL
    let quality: String?
    let mimeType: String?
    let isLive: Bool?

    var displayTitle: String {
        title?.isEmpty == false ? title! : url.host ?? url.absoluteString
    }

    var detail: String {
        [quality, mimeType, isLive == true ? "live" : nil]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var isDownloadable: Bool {
        url.pipIsDownloadableFileURL
    }

    var playbackRank: Int {
        let ext = url.pathExtension.lowercased()
        if ext == "m3u8" { return 4000 }
        if ["mp4", "m4v", "mov"].contains(ext) { return 3000 }
        if ["mp3", "aac", "m4a"].contains(ext) { return 1000 }
        return 2000
    }

    init(id: String, title: String?, url: URL, quality: String?, mimeType: String?, isLive: Bool?) {
        self.id = id
        self.title = title
        self.url = url
        self.quality = quality
        self.mimeType = mimeType
        self.isLive = isLive
    }

    func withFallbackTitle(_ fallbackTitle: String?) -> ResolvedStream {
        ResolvedStream(
            id: id,
            title: title ?? fallbackTitle,
            url: url,
            quality: quality,
            mimeType: mimeType,
            isLive: isLive
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case quality
        case mimeType
        case mimeTypeSnake = "mime_type"
        case isLive
        case isLiveSnake = "is_live"
        case formatID = "format_id"
        case formatNote = "format_note"
        case format
        case resolution
        case ext
        case height
        case width
        case protocolName = "protocol"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let urlString = try container.decode(String.self, forKey: .url)
        guard let decodedURL = URL(string: urlString) else {
            throw DecodingError.dataCorruptedError(forKey: .url, in: container, debugDescription: "Invalid stream URL")
        }

        let height = try container.decodeIfPresent(Int.self, forKey: .height)
        let width = try container.decodeIfPresent(Int.self, forKey: .width)
        let formatID = try container.decodeIfPresent(String.self, forKey: .formatID)
        let explicitQuality = try container.decodeIfPresent(String.self, forKey: .quality)
        let resolution = try container.decodeIfPresent(String.self, forKey: .resolution)
        let format = try container.decodeIfPresent(String.self, forKey: .format)
        let formatNote = try container.decodeIfPresent(String.self, forKey: .formatNote)
        let inferredQuality = explicitQuality ?? resolution ?? formatNote ?? format ?? height.map { "\($0)p" } ?? width.map { "\($0)w" }
        let ext = try container.decodeIfPresent(String.self, forKey: .ext)

        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? formatID ?? inferredQuality ?? urlString
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.url = decodedURL
        self.quality = inferredQuality
        self.mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType) ?? container.decodeIfPresent(String.self, forKey: .mimeTypeSnake) ?? inferredResolverMimeType(forExtension: ext ?? decodedURL.pathExtension)
        self.isLive = try container.decodeIfPresent(Bool.self, forKey: .isLive) ?? container.decodeIfPresent(Bool.self, forKey: .isLiveSnake)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(url.absoluteString, forKey: .url)
        try container.encodeIfPresent(quality, forKey: .quality)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(isLive, forKey: .isLive)
    }
}

struct ResolverResponse: Codable {
    let title: String?
    let streams: [ResolvedStream]

    enum CodingKeys: String, CodingKey {
        case title
        case streams
        case formats
        case url
        case id
    }

    init(title: String?, streams: [ResolvedStream]) {
        self.title = title
        self.streams = streams.map { $0.withFallbackTitle(title) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(streams, forKey: .streams)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let title = try container.decodeIfPresent(String.self, forKey: .title)
        let decodedStreams = try container.decodeIfPresent([ResolvedStream].self, forKey: .streams)
            ?? container.decodeIfPresent([ResolvedStream].self, forKey: .formats)

        if let decodedStreams {
            self.init(title: title, streams: decodedStreams)
            return
        }

        let urlString = try container.decode(String.self, forKey: .url)
        guard let url = URL(string: urlString) else {
            throw DecodingError.dataCorruptedError(forKey: .url, in: container, debugDescription: "Invalid stream URL")
        }
        let id = try container.decodeIfPresent(String.self, forKey: .id) ?? urlString
        self.init(title: title, streams: [ResolvedStream(id: id, title: title, url: url, quality: nil, mimeType: url.pipInferredMimeType, isLive: nil)])
    }
}

private func inferredResolverMimeType(forExtension ext: String?) -> String? {
    switch ext?.lowercased() {
    case "m3u8": return "application/vnd.apple.mpegurl"
    case "mp4", "m4v": return "video/mp4"
    case "mov": return "video/quicktime"
    case "mp3": return "audio/mpeg"
    case "aac": return "audio/aac"
    case "m4a": return "audio/mp4"
    default: return nil
    }
}
