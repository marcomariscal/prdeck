import Foundation

struct RepoSnapshotStore {
    private struct Snapshot: Codable {
        let updatedAt: Date
        let repos: [String]
    }

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
            return
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = (base ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("PRDeck", isDirectory: true)
        self.fileURL = directory.appendingPathComponent("repos.json", isDirectory: false)
    }

    func loadRepos() -> [String]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return (try? JSONDecoder.prdeck.decode(Snapshot.self, from: data))?.repos
    }

    func saveRepos(_ repos: [String]) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let snapshot = Snapshot(updatedAt: Date(), repos: repos)
            let data = try JSONEncoder.prdeck.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Cache writes are best-effort.
        }
    }
}
