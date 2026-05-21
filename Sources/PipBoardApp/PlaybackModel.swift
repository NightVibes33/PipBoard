import Foundation
import UIKit

@MainActor
final class PlaybackModel: ObservableObject {
    @Published var videoURLText = ""
    @Published var resolverEndpointText = UserDefaults.standard.string(forKey: "resolverEndpoint") ?? ""
    @Published var activeVideoURL: URL?
    @Published var browserURL: URL?
    @Published var resolvedStreams: [ResolvedStream] = []
    @Published var resolveState: ResolveState = .idle
    @Published var message = "Share, paste, or browse a video link. Direct streams play locally; platform links use your resolver endpoint."

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
        } catch {
            resolveState = .failed(error.localizedDescription)
            browserURL = url
            message = "Resolver failed: \(error.localizedDescription)"
        }
    }

    func play(stream: ResolvedStream) {
        activeVideoURL = stream.url
        message = "Playing \(stream.displayTitle). Use the PiP button in the player."
    }

    func openInBrowser() {
        guard let url = cleanedURL(from: videoURLText) else {
            message = "Enter a valid URL before opening the browser."
            return
        }
        browserURL = url
        message = "Opened browser fallback for \(url.host ?? url.absoluteString)."
    }

    func saveEndpoint() {
        UserDefaults.standard.set(resolverEndpointText.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "resolverEndpoint")
    }

    private func cleanedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return URL(string: trimmed)
    }
}
