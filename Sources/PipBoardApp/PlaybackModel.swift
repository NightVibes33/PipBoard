import Foundation
import UIKit

@MainActor
final class PlaybackModel: ObservableObject {
    @Published var videoURLText = ""
    @Published var resolverEndpointText = UserDefaults.standard.string(forKey: "resolverEndpoint") ?? ""
    @Published var activeVideoURL: URL?
    @Published var browserURL: URL?
    @Published var resolvedStreams: [ResolvedStream] = []
    @Published var downloads: [DownloadedVideo] = DownloadStore.load()
    @Published var resolveState: ResolveState = .idle
    @Published var downloadState: DownloadState = .idle
    @Published var message = "Share, paste, browse, resolve, download, and PiP video links."

    private let resolver: VideoResolving

    init(resolver: VideoResolving = VideoResolver()) {
        self.resolver = resolver
    }

    func handleIncoming(url: URL) {
        guard url.scheme == "pipboard",
              url.host == "open",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let rawValue = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let decodedURL = URL(string: rawValue)
        else {
            message = "The shared item did not contain a usable URL."
            return
        }

        videoURLText = decodedURL.absoluteString
        Task { await resolveFromText() }
    }

    func openClipboard() {
        guard let clipboardText = UIPasteboard.general.string else {
            message = "Clipboard does not contain text."
            return
        }
        videoURLText = clipboardText
        Task { await resolveFromText() }
    }

    func resolveFromText() async {
        guard let url = cleanedURL(from: videoURLText) else {
            resolveState = .failed("Enter a valid URL.")
            message = "Enter a valid URL."
            return
        }

        saveEndpoint()
        resolvedStreams = []
        browserURL = nil
        resolveState = .resolving
        message = "Resolving \(url.host ?? url.absoluteString)..."

        do {
            let streams = try await resolver.resolve(inputURL: url, endpoint: cleanedURL(from: resolverEndpointText))
            resolvedStreams = streams
            resolveState = .resolved
            play(stream: streams[0])
        } catch ResolverError.missingEndpoint(_) {
            openWebPlayer(for: url, reason: "Opened web player. Add an optional resolver only when you want native streams or downloads for platform links.")
        } catch {
            resolveState = .failed(error.localizedDescription)
            openWebPlayer(for: url, reason: "Native resolve failed, so the link opened in the web player.")
        }
    }

    func play(stream: ResolvedStream) {
        activeVideoURL = stream.url
        message = "Playing \(stream.displayTitle). Use the PiP button in the player."
    }

    func play(download: DownloadedVideo) {
        guard FileManager.default.fileExists(atPath: download.localURL.path) else {
            downloads.removeAll { $0.id == download.id }
            DownloadStore.save(downloads)
            message = "Downloaded file is missing and was removed from the library."
            return
        }
        activeVideoURL = download.localURL
        message = "Playing downloaded file: \(download.title)."
    }

    func openInBrowser() {
        guard let url = cleanedURL(from: videoURLText) else {
            message = "Enter a valid URL before opening the browser."
            return
        }
        openWebPlayer(for: url, reason: "Opened web player for \(url.host ?? url.absoluteString).")
    }

    private func openWebPlayer(for url: URL, reason: String) {
        activeVideoURL = nil
        resolveState = .resolved
        browserURL = url.pipBrowserPlaybackURL
        message = reason
    }

    func copy(stream: ResolvedStream) {
        UIPasteboard.general.string = stream.url.absoluteString
        message = "Copied stream URL."
    }

    func importLocalFile(_ url: URL) {
        let canAccess = url.startAccessingSecurityScopedResource()
        defer { if canAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            try DownloadStore.ensureDirectory()
            let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
            let name = url.deletingPathExtension().lastPathComponent.isEmpty ? "Imported" : url.deletingPathExtension().lastPathComponent
            let filename = "\(name)-\(UUID().uuidString.prefix(8)).\(ext)"
            let destination = DownloadStore.downloadsDirectory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: url, to: destination)
            let saved = DownloadedVideo(
                id: UUID(),
                title: name,
                sourceURL: url,
                localFilename: filename,
                createdAt: Date(),
                byteCount: fileSize(at: destination) ?? 0
            )
            downloads.insert(saved, at: 0)
            DownloadStore.save(downloads)
            play(download: saved)
        } catch {
            message = "Import failed: \(error.localizedDescription)"
        }
    }

    func download(stream: ResolvedStream) async {
        guard stream.url.pipIsDownloadableFileURL else {
            downloadState = .failed("HLS/manifest streams need the resolver to return a downloadable MP4 or packaged file.")
            message = "Download unavailable for this stream type. Choose an MP4/progressive stream."
            return
        }

        downloadState = .downloading(stream.displayTitle)
        message = "Downloading \(stream.displayTitle)..."

        do {
            try DownloadStore.ensureDirectory()
            let (temporaryURL, response) = try await URLSession.shared.download(from: stream.url)
            let filename = safeFilename(for: stream)
            let destination = DownloadStore.downloadsDirectory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            let byteCount = fileSize(at: destination) ?? response.expectedContentLength
            let saved = DownloadedVideo(
                id: UUID(),
                title: stream.displayTitle,
                sourceURL: stream.url,
                localFilename: filename,
                createdAt: Date(),
                byteCount: max(byteCount, 0)
            )
            downloads.insert(saved, at: 0)
            DownloadStore.save(downloads)
            downloadState = .completed(saved.title)
            message = "Downloaded \(saved.title)."
        } catch {
            downloadState = .failed(error.localizedDescription)
            message = "Download failed: \(error.localizedDescription)"
        }
    }

    func clearDownloads() {
        for download in downloads {
            DownloadStore.delete(download)
        }
        downloads.removeAll()
        DownloadStore.save(downloads)
        message = "Cleared downloads."
    }

    func deleteDownloads(at offsets: IndexSet) {
        for index in offsets {
            DownloadStore.delete(downloads[index])
        }
        for index in offsets.sorted(by: >) {
            downloads.remove(at: index)
        }
        DownloadStore.save(downloads)
    }

    func saveEndpoint() {
        UserDefaults.standard.set(resolverEndpointText.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "resolverEndpoint")
    }

    private func cleanedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://\(trimmed)")
    }

    private func safeFilename(for stream: ResolvedStream) -> String {
        let base = stream.displayTitle
            .replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
        let fallback = stream.url.deletingPathExtension().lastPathComponent.isEmpty ? "video" : stream.url.deletingPathExtension().lastPathComponent
        let name = base.isEmpty ? fallback : base
        let ext = stream.url.pathExtension.isEmpty ? "mp4" : stream.url.pathExtension
        return "\(name)-\(UUID().uuidString.prefix(8)).\(ext)"
    }

    private func fileSize(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize.map(Int64.init)
    }

}
