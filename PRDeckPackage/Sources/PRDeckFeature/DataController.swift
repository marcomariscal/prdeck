import Foundation

@MainActor
public final class DataController: ObservableObject {
    @Published public private(set) var items: [PRItem] = []
    @Published public private(set) var isRefreshing = false
    @Published public var lastError: String?
    @Published public var selectedId: PRItem.ID?
    @Published public private(set) var knownRepos: [String] = []

    private let dataSource: GitHubDataSource
    private let snapshotStore: SnapshotStore
    private let repoSnapshotStore: RepoSnapshotStore
    private var refreshTask: Task<Void, Never>?

    public convenience init() {
        self.init(dataSource: .init(), snapshotStore: .init(), repoSnapshotStore: .init())
    }

    init(dataSource: GitHubDataSource, snapshotStore: SnapshotStore, repoSnapshotStore: RepoSnapshotStore) {
        self.dataSource = dataSource
        self.snapshotStore = snapshotStore
        self.repoSnapshotStore = repoSnapshotStore

        if let snapshot = snapshotStore.loadSnapshot() {
            items = Self.sortItems(snapshot)
        }

        if let repos = repoSnapshotStore.loadRepos() {
            knownRepos = repos
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    public func start() {
        Task { await refresh() }
        startAutoRefresh()
    }

    public func startAutoRefresh(intervalSeconds: TimeInterval = 30) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalSeconds))
                await self.refresh()
            }
        }
    }

    public func refresh(reloadRepos: Bool = false) async {
        if isRefreshing { return }
        isRefreshing = true
        lastError = nil

        defer { isRefreshing = false }

        let reposTask: Task<[String]?, Never>? = {
            guard reloadRepos else { return nil }
            return Task { try? await dataSource.fetchRepoDirectory() }
        }()

        do {
            let fetched = try await dataSource.fetchAll()
            let ordered = Self.sortItems(fetched)
            items = ordered
            snapshotStore.saveSnapshot(ordered)

            if let selectedId, !ordered.contains(where: { $0.id == selectedId }) {
                self.selectedId = nil
            }
        } catch {
            lastError = String(describing: error)
        }

        if let repos = await reposTask?.value, !repos.isEmpty {
            knownRepos = repos
            repoSnapshotStore.saveRepos(repos)
        }
    }

    private static func sortItems(_ items: [PRItem]) -> [PRItem] {
        items.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            if lhs.repository.nameWithOwner != rhs.repository.nameWithOwner {
                return lhs.repository.nameWithOwner.localizedCaseInsensitiveCompare(rhs.repository.nameWithOwner) == .orderedAscending
            }
            if lhs.number != rhs.number { return lhs.number > rhs.number }
            return lhs.id < rhs.id
        }
    }
}
