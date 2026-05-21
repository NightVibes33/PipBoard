import Foundation
import Social
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
    private var sharedURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        placeholder = "Open this video URL in PipBoard"
        loadSharedURL()
    }

    override func isContentValid() -> Bool {
        sharedURL != nil
    }

    override func didSelectPost() {
        guard let sharedURL else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }

        openHostApp(with: sharedURL)
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func loadSharedURL() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = item.attachments
        else { return }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                    DispatchQueue.main.async {
                        self?.sharedURL = item as? URL
                        self?.validateContent()
                    }
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { [weak self] item, _ in
                    DispatchQueue.main.async {
                        self?.sharedURL = item as? URL
                        self?.validateContent()
                    }
                }
                return
            }
        }
    }

    private func openHostApp(with url: URL) {
        var components = URLComponents()
        components.scheme = "pipboard"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString)
        ]

        guard let callbackURL = components.url else { return }
        extensionContext?.open(callbackURL)
    }
}
