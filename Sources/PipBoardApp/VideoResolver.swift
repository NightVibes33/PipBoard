import Foundation

protocol VideoResolving {
    func resolve(inputURL: URL, endpoint: URL?) async throws -> [ResolvedStream]
}

struct VideoResolver: VideoResolving {
    func resolve(inputURL: URL, endpoint: URL?) async throws -> [ResolvedStream] {
        if inputURL.isDirectMediaURL {
            return [ResolvedStream(
                id: inputURL.absoluteString,
                title: inputURL.lastPathComponent.isEmpty ? inputURL.host : inputURL.lastPathComponent,
                url: inputURL,
                quality: "direct",
                mimeType: inputURL.inferredMimeType,
                isLive: inputURL.pathExtension.lowercased() == "m3u8"
            )]
        }

        guard let endpoint else {
            throw ResolverError.missingEndpoint(inputURL.host ?? inputURL.absoluteString)
        }

        return try await resolveRemotely(inputURL: inputURL, endpoint: endpoint)
    }

    private func resolveRemotely(inputURL: URL, endpoint: URL) async throws -> [ResolvedStream] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["url": inputURL.absoluteString])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode
        else {
            throw ResolverError.remoteFailed
        }

        let decoded = try JSONDecoder().decode(ResolverResponse.self, from: data)
        let streams = decoded.streams.filter { $0.url.isPlayableStreamURL }
        guard streams.isEmpty == false else { throw ResolverError.noPlayableStreams }
        return streams
    }
}

enum ResolverError: LocalizedError {
    case missingEndpoint(String)
    case remoteFailed
    case noPlayableStreams

    var errorDescription: String? {
        switch self {
        case .missingEndpoint(let source):
            return "No resolver endpoint set for \(source). Add a yt-dlp compatible API endpoint."
        case .remoteFailed:
            return "The resolver endpoint failed."
        case .noPlayableStreams:
            return "The resolver did not return an AVPlayer-compatible stream."
        }
    }
}

private extension URL {
    var isDirectMediaURL: Bool {
        isPlayableStreamURL && ["mp4", "m4v", "mov", "m3u8", "mpd", "webm", "mp3", "aac", "m4a"].contains(pathExtension.lowercased())
    }

    var isPlayableStreamURL: Bool {
        guard ["http", "https", "file"].contains(scheme?.lowercased()) else { return false }
        return true
    }

    var inferredMimeType: String? {
        switch pathExtension.lowercased() {
        case "m3u8": return "application/vnd.apple.mpegurl"
        case "mp4", "m4v": return "video/mp4"
        case "mov": return "video/quicktime"
        case "webm": return "video/webm"
        case "mp3": return "audio/mpeg"
        case "aac": return "audio/aac"
        case "m4a": return "audio/mp4"
        default: return nil
        }
    }
}
