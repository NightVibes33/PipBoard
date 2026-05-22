import Foundation

protocol VideoResolving {
    func resolve(inputURL: URL, endpoint: URL?) async throws -> [ResolvedStream]
}

struct VideoResolver: VideoResolving {
    func resolve(inputURL: URL, endpoint: URL?) async throws -> [ResolvedStream] {
        if inputURL.pipIsDirectPlayableMediaURL {
            return [ResolvedStream(
                id: inputURL.absoluteString,
                title: inputURL.lastPathComponent.isEmpty ? inputURL.host : inputURL.lastPathComponent,
                url: inputURL,
                quality: "direct",
                mimeType: inputURL.pipInferredMimeType,
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
        request.timeoutInterval = 75
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("PipBoard/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(["url": inputURL.absoluteString])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ResolverError.remoteFailed("No HTTP response from resolver.")
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw ResolverError.remoteFailed("HTTP \(httpResponse.statusCode). \(body)")
        }

        let decoded = try JSONDecoder().decode(ResolverResponse.self, from: data)
        let streams = decoded.streams
            .filter { $0.url.pipIsPlayableURL }
            .sorted { lhs, rhs in
                if lhs.playbackRank == rhs.playbackRank { return lhs.id < rhs.id }
                return lhs.playbackRank > rhs.playbackRank
            }
        guard streams.isEmpty == false else { throw ResolverError.noPlayableStreams }
        return streams
    }
}

enum ResolverError: LocalizedError {
    case missingEndpoint(String)
    case remoteFailed(String)
    case noPlayableStreams

    var errorDescription: String? {
        switch self {
        case .missingEndpoint(let source):
            return "No resolver endpoint set for \(source). Add a yt-dlp compatible API endpoint."
        case .remoteFailed(let detail):
            return "The resolver endpoint failed. \(detail)"
        case .noPlayableStreams:
            return "The resolver did not return an AVPlayer-compatible stream."
        }
    }
}
