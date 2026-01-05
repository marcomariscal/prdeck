import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject var dataController: DataController

    @AppStorage(PRDeckDefaultsKey.showAll) private var showAll = false
    @AppStorage(PRDeckDefaultsKey.excludedRepos) private var excludedRepos = ""
    @AppStorage(PRDeckDefaultsKey.zoomStep) private var zoomStep = 0
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var keyMonitor: KeyEventMonitor?
    @State private var isRepoFilterPresented = false
    @State private var repoFilterSearchText = ""

    private var computedZoomScale: CGFloat {
        let clamped = max(-3, min(6, zoomStep))
        return pow(1.12, CGFloat(clamped))
    }

    private var excludedRepoSet: Set<String> {
        let normalized = excludedRepos
            .replacingOccurrences(of: "\n", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Set(normalized)
    }

    private func setExcludedRepoSet(_ set: Set<String>) {
        excludedRepos = set
            .map { $0.lowercased() }
            .sorted()
            .joined(separator: "\n")
    }

    private var availableRepos: [String] {
        Array(Set(dataController.items.map(\.repository.nameWithOwner)))
            .sorted()
    }

    private var visibleReposForFiltering: [String] {
        let q = repoFilterSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return availableRepos }
        return availableRepos.filter { $0.lowercased().contains(q) }
    }

    private var visibleItems: [PRItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = dataController.items.filter { item in
            if excludedRepoSet.contains(item.repository.nameWithOwner.lowercased()) { return false }
            if !showAll, !item.needsAttention { return false }
            if q.isEmpty { return true }

            let needle = q.lowercased()
            if item.repository.nameWithOwner.lowercased().contains(needle) { return true }
            if item.title.lowercased().contains(needle) { return true }
            if String(item.number).contains(needle) { return true }
            return false
        }

        return filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if let error = dataController.lastError {
                errorBanner(error)
            }

            list
        }
        .onAppear { installKeyMonitor() }
        .onDisappear { keyMonitor?.stop() }
        .environment(\.prdeckZoomScale, computedZoomScale)
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .font(.system(size: 13 * computedZoomScale))

                Picker("", selection: $showAll) {
                    Text("Needs attention").tag(false)
                    Text("Show all").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Button("Filter…") {
                    isRepoFilterPresented = true
                }
                .buttonStyle(.bordered)
                .popover(isPresented: $isRepoFilterPresented, arrowEdge: .top) {
                    repoFilterPopover
                }

                if dataController.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .controlSize(.large)
        }
        .padding(10)
        .background(.regularMaterial)
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 8) {
            Text(error)
                .lineLimit(2)
                .font(.system(size: 11 * computedZoomScale))
            Spacer()
            Button("Retry") { Task { await dataController.refresh() } }
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.12))
    }

    private var list: some View {
        List(visibleItems, selection: $dataController.selectedId) { item in
            PRRowView(item: item)
                .tag(item.id)
        }
        .listStyle(.inset)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        let monitor = KeyEventMonitor { event in
            handleKeyDown(event)
        }
        monitor.start()
        keyMonitor = monitor
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCommandOnly = flags.contains(.command) && !flags.contains(.control) && !flags.contains(.option) && !flags.contains(.function)

        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if hasCommandOnly {
            switch key {
            case "=", "+":
                zoomStep = min(6, zoomStep + 1)
                return true
            case "-":
                zoomStep = max(-3, zoomStep - 1)
                return true
            case "0":
                zoomStep = 0
                return true
            default:
                break
            }
        }

        let hasNonShiftModifiers = flags.contains(.command) || flags.contains(.control) || flags.contains(.option) || flags.contains(.function)
        if hasNonShiftModifiers { return false }

        if searchFocused {
            if key == "\u{1b}" { // escape
                searchFocused = false
                return true
            }
            return false
        }

        switch key {
        case "j":
            moveSelection(delta: 1)
            return true
        case "k":
            moveSelection(delta: -1)
            return true
        case "\r":
            openSelectedPR()
            return true
        case "r":
            Task { await dataController.refresh() }
            return true
        case "t":
            showAll.toggle()
            return true
        case "c":
            openChecks(preferFailingURL: false)
            return true
        case "f":
            openChecks(preferFailingURL: true)
            return true
        default:
            return false
        }
    }

    private func moveSelection(delta: Int) {
        guard !visibleItems.isEmpty else { return }

        let currentIndex = visibleItems.firstIndex { $0.id == dataController.selectedId }
        let nextIndex: Int = {
            guard let currentIndex else { return 0 }
            return max(0, min(visibleItems.count - 1, currentIndex + delta))
        }()

        dataController.selectedId = visibleItems[nextIndex].id
    }

    private func openSelectedPR() {
        guard let selected = visibleItems.first(where: { $0.id == dataController.selectedId }) else { return }
        NSWorkspace.shared.open(selected.url)
    }

    private func openChecks(preferFailingURL: Bool) {
        guard let selected = visibleItems.first(where: { $0.id == dataController.selectedId }) else { return }

        if preferFailingURL, let failing = selected.failingCheckURL {
            NSWorkspace.shared.open(failing)
            return
        }

        guard let checksURL = URL(string: selected.url.absoluteString + "/checks") else { return }
        NSWorkspace.shared.open(checksURL)
    }

    private var repoFilterPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exclude repositories")
                .font(.headline)

            TextField("Filter repos…", text: $repoFilterSearchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360)

            if !excludedRepoSet.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Excluded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(excludedRepoSet.sorted(), id: \.self) { repo in
                        HStack {
                            Text(repo)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            Button("Remove") {
                                var set = excludedRepoSet
                                set.remove(repo)
                                setExcludedRepoSet(set)
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Select All") {
                        var set = excludedRepoSet
                        for repo in visibleReposForFiltering {
                            set.insert(repo.lowercased())
                        }
                        setExcludedRepoSet(set)
                    }
                    .controlSize(.small)

                    Button("Select None") {
                        var set = excludedRepoSet
                        for repo in visibleReposForFiltering {
                            set.remove(repo.lowercased())
                        }
                        setExcludedRepoSet(set)
                    }
                    .controlSize(.small)

                    Spacer()
                }

                List(visibleReposForFiltering, id: \.self) { repo in
                    Toggle(repo, isOn: .init(
                        get: { excludedRepoSet.contains(repo.lowercased()) },
                        set: { isOn in
                            var set = excludedRepoSet
                            if isOn {
                                set.insert(repo.lowercased())
                            } else {
                                set.remove(repo.lowercased())
                            }
                            setExcludedRepoSet(set)
                        }
                    ))
                    .toggleStyle(.checkbox)
                }
                .frame(width: 380, height: 220)
            }

            HStack {
                Button("Clear") {
                    setExcludedRepoSet([])
                }
                .controlSize(.regular)

                Spacer()
                Button("Done") { isRepoFilterPresented = false }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.regular)
            }
        }
        .padding(12)
    }
}
