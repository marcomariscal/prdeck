import Foundation

@MainActor
public final class DataController: ObservableObject {
    @Published public private(set) var items: [PRItem] = []
    @Published public private(set) var isRefreshing = false
    @Published public var lastError: String?
    @Published public var selectedId: PRItem.ID?

    private let dataSource: GitHubDataSource
    private let snapshotStore: SnapshotStore
    private var priorOrder: [PRItem.ID] = []
    private var refreshTask: Task<Void, Never>?

    public convenience init() {
        self.init(dataSource: .init(), snapshotStore: .init())
    }

    init(dataSource: GitHubDataSource, snapshotStore: SnapshotStore) {
        self.dataSource = dataSource
        self.snapshotStore = snapshotStore

        if let snapshot = snapshotStore.loadSnapshot() {
            items = snapshot
            priorOrder = snapshot.map(\.id)
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

    public func refresh() async {
        if isRefreshing { return }
        isRefreshing = true
        lastError = nil

        defer { isRefreshing = false }

        do {
            let fetched = try await dataSource.fetchAll()
            let ordered = applyStableOrdering(fetched)
            items = ordered
            snapshotStore.saveSnapshot(ordered)

            if let selectedId, !ordered.contains(where: { $0.id == selectedId }) {
                self.selectedId = nil
            }
        } catch {
            lastError = String(describing: error)
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
