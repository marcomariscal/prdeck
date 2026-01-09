import Foundation

struct RepoSnapshot: Codable {
    let updatedAt: Date
    let repos: [String]
}

struct RepoSnapshotStore {
    private let store: PersistentStore<RepoSnapshot>

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.store = .init(fileURL: fileURL)
        } else {
            self.store = .init(fileName: "repos.json")
        }
    }

    func loadRepos() -> [String]? {
        store.load()?.repos
    }

    func saveRepos(_ repos: [String]) {
        store.save(.init(updatedAt: Date(), repos: repos))
    }
}
