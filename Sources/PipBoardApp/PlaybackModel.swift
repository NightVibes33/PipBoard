import Foundation

@MainActor
final class PlaybackModel: ObservableObject {
    @Published var videoURLText = ""
    @Published var activeVideoURL: URL?
    @Published var message = "Share a direct video URL, HLS stream, or paste one here."

    func handleIncoming(url: URL) {
        guard url.scheme == "pipboard",
              url.host == "open",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let rawValue = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let decodedURL = URL(string: rawValue)
        else {
            message = "The shared item did not contain a usable video URL."
            return
        }

        videoURLText = decodedURL.absoluteString
        play(url: decodedURL)
    }

    func playFromText() {
        guard let url = URL(string: videoURLText.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https", "file"].contains(url.scheme?.lowercased())
        else {
            message = "Enter a valid http, https, or file URL."
            return
        }

        play(url: url)
    }

    private func play(url: URL) {
        activeVideoURL = url
        let name = url.lastPathComponent.isEmpty ? (url.host ?? "video") : url.lastPathComponent
        message = "Playing \(name). Use the PiP button in the player."
    }
}
