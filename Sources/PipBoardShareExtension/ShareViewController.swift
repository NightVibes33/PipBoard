import Foundation
import Social
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
    private var sharedURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        placeholder = "Open this link in PipBoard"
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

        if let urlProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            loadURL(from: urlProvider, typeIdentifier: UTType.url.identifier)
            return
        }

        if let textProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            loadURL(from: textProvider, typeIdentifier: UTType.plainText.identifier)
        }
    }

    private func loadURL(from provider: NSItemProvider, typeIdentifier: String) {
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.sharedURL = self?.extractURL(from: item)
                self?.validateContent()
            }
        }
    }

    private func extractURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let string = item as? String { return URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let data = item as? Data,
           let string = String(data: data, encoding: .utf8) {
            return URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
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
