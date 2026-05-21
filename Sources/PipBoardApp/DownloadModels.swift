import Foundation

struct DownloadedVideo: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var sourceURL: URL
    var localFilename: String
    var createdAt: Date
    var byteCount: Int64

    var localURL: URL {
        DownloadStore.downloadsDirectory.appendingPathComponent(localFilename)
    }

    var detail: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: byteCount)) · \(createdAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

enum DownloadState: Equatable {
    case idle
    case downloading(String)
    case completed(String)
    case failed(String)
}

enum DownloadStore {
    static var downloadsDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("PipBoard Downloads", isDirectory: true)
    }

    private static var indexURL: URL {
        downloadsDirectory.appendingPathComponent("downloads.json")
    }

    static func load() -> [DownloadedVideo] {
        do {
            try ensureDirectory()
            let data = try Data(contentsOf: indexURL)
            return try JSONDecoder().decode([DownloadedVideo].self, from: data)
        } catch {
            return []
        }
    }

    static func save(_ downloads: [DownloadedVideo]) {
        do {
            try ensureDirectory()
            let data = try JSONEncoder().encode(downloads)
            try data.write(to: indexURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save downloads: \(error)")
        }
    }

    static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
    }

    static func delete(_ download: DownloadedVideo) {
        try? FileManager.default.removeItem(at: download.localURL)
    }
}
