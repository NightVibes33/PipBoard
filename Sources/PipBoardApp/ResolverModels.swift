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
        if let title, title.isEmpty == false { return title }
        return url.host ?? url.absoluteString
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
        let mime = mimeType?.lowercased() ?? ""
        if ext == "m3u8" || mime.contains("mpegurl") { return 4000 }
        if ["mp4", "m4v", "mov"].contains(ext) || mime.contains("video/mp4") || mime.contains("quicktime") { return 3000 }
        if ["mp3", "aac", "m4a"].contains(ext) || mime.hasPrefix("audio/") { return 1000 }
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
        let urlString = try decodeFlexibleString(from: container, forKey: .url)
        guard let decodedURL = URL(string: urlString) else {
            throw DecodingError.dataCorruptedError(forKey: .url, in: container, debugDescription: "Invalid stream URL")
        }

        let height = decodeFlexibleIntIfPresent(from: container, forKey: .height)
        let width = decodeFlexibleIntIfPresent(from: container, forKey: .width)
        let formatID = decodeFlexibleStringIfPresent(from: container, forKey: .formatID)
        let explicitQuality = decodeFlexibleStringIfPresent(from: container, forKey: .quality)
        let resolution = decodeFlexibleStringIfPresent(from: container, forKey: .resolution)
        let format = decodeFlexibleStringIfPresent(from: container, forKey: .format)
        let formatNote = decodeFlexibleStringIfPresent(from: container, forKey: .formatNote)
        let inferredQuality = explicitQuality ?? resolution ?? formatNote ?? format ?? height.map { "\($0)p" } ?? width.map { "\($0)w" }
        let ext = decodeFlexibleStringIfPresent(from: container, forKey: .ext)

        self.id = decodeFlexibleStringIfPresent(from: container, forKey: .id) ?? formatID ?? inferredQuality ?? urlString
        self.title = decodeFlexibleStringIfPresent(from: container, forKey: .title)
        self.url = decodedURL
        self.quality = inferredQuality
        self.mimeType = decodeFlexibleStringIfPresent(from: container, forKey: .mimeType) ?? decodeFlexibleStringIfPresent(from: container, forKey: .mimeTypeSnake) ?? inferredResolverMimeType(forExtension: ext ?? decodedURL.pathExtension)
        self.isLive = decodeFlexibleBoolIfPresent(from: container, forKey: .isLive) ?? decodeFlexibleBoolIfPresent(from: container, forKey: .isLiveSnake)
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
        let title = decodeFlexibleStringIfPresent(from: container, forKey: .title)
        let streamEntries = try decodeLossyStreams(from: container, forKey: .streams)
        let formatEntries = streamEntries == nil ? try decodeLossyStreams(from: container, forKey: .formats) : nil
        let decodedStreams = streamEntries ?? formatEntries

        if let decodedStreams {
            self.init(title: title, streams: decodedStreams)
            return
        }

        let urlString = try decodeFlexibleString(from: container, forKey: .url)
        guard let url = URL(string: urlString) else {
            throw DecodingError.dataCorruptedError(forKey: .url, in: container, debugDescription: "Invalid stream URL")
        }
        let id = decodeFlexibleStringIfPresent(from: container, forKey: .id) ?? urlString
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


private struct LossyResolvedStream: Decodable {
    let value: ResolvedStream?

    init(from decoder: Decoder) throws {
        value = try? ResolvedStream(from: decoder)
    }
}

private func decodeLossyStreams<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) throws -> [ResolvedStream]? {
    guard container.contains(key) else { return nil }
    return try container.decodeIfPresent([LossyResolvedStream].self, forKey: key)?.compactMap(\.value)
}

private func decodeFlexibleString<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) throws -> String {
    if let value = decodeFlexibleStringIfPresent(from: container, forKey: key) { return value }
    throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Missing string value for \(key.stringValue)"))
}

private func decodeFlexibleStringIfPresent<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) -> String? {
    if let value = try? container.decodeIfPresent(String.self, forKey: key) { return value }
    if let value = try? container.decodeIfPresent(Int.self, forKey: key) { return String(value) }
    if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
        let rounded = value.rounded()
        return value == rounded ? String(Int64(rounded)) : String(value)
    }
    if let value = try? container.decodeIfPresent(Bool.self, forKey: key) { return String(value) }
    return nil
}

private func decodeFlexibleIntIfPresent<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) -> Int? {
    if let value = try? container.decodeIfPresent(Int.self, forKey: key) { return value }
    if let value = try? container.decodeIfPresent(Double.self, forKey: key) { return Int(value) }
    if let value = try? container.decodeIfPresent(String.self, forKey: key) {
        return Int(value) ?? Double(value).map(Int.init)
    }
    return nil
}

private func decodeFlexibleBoolIfPresent<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) -> Bool? {
    if let value = try? container.decodeIfPresent(Bool.self, forKey: key) { return value }
    if let value = try? container.decodeIfPresent(Int.self, forKey: key) { return value != 0 }
    if let value = try? container.decodeIfPresent(String.self, forKey: key) {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil
        }
    }
    return nil
}
