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
}

struct ResolverResponse: Codable {
    let title: String?
    let streams: [ResolvedStream]
}
