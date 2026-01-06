import Foundation

@MainActor
public final class DataController: ObservableObject {
    @Published public private(set) var items: [PRItem] = []
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var lastSuccessfulRefreshAt: Date?
    @Published public var lastError: String?
    @Published public var selectedId: PRItem.ID?
    @Published public private(set) var knownRepos: [String] = []

    private let dataSource: GitHubDataSource
    private let snapshotStore: SnapshotStore
    private let repoSnapshotStore: RepoSnapshotStore
    private var priorOrder: [PRItem.ID] = []
    private var refreshTask: Task<Void, Never>?

    public convenience init() {
        self.init(dataSource: .init(), snapshotStore: .init(), repoSnapshotStore: .init())
    }

    init(dataSource: GitHubDataSource, snapshotStore: SnapshotStore, repoSnapshotStore: RepoSnapshotStore) {
        self.dataSource = dataSource
        self.snapshotStore = snapshotStore
        self.repoSnapshotStore = repoSnapshotStore

        if let snapshot = snapshotStore.loadSnapshot() {
            items = snapshot
            priorOrder = snapshot.map(\.id)
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
            let ordered = applyStableOrdering(fetched)
            items = ordered
            snapshotStore.saveSnapshot(ordered)
            lastSuccessfulRefreshAt = .now

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

    private func applyStableOrdering(_ incoming: [PRItem]) -> [PRItem] {
        let byId = Dictionary(incoming.map { ($0.id, $0) }, uniquingKeysWith: { newest, _ in newest })

        var seen = Set<PRItem.ID>()
        var ordered: [PRItem] = []

        for id in priorOrder {
            if let item = byId[id] {
                ordered.append(item)
                seen.insert(id)
            }
        }

        let newItems = incoming
            .filter { !seen.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }

        ordered.append(contentsOf: newItems)
        priorOrder = ordered.map(\.id)
        return ordered
    }
}
