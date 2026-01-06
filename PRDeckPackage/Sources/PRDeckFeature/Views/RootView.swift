import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject var dataController: DataController

    @AppStorage(PRDeckDefaultsKey.showAll) private var showAll = false
    @AppStorage(PRDeckDefaultsKey.repoFilterMode) private var repoFilterModeRaw = RepoFilterMode.exclude.rawValue
    @AppStorage(PRDeckDefaultsKey.excludedRepos) private var excludedRepos = ""
    @AppStorage(PRDeckDefaultsKey.includedRepos) private var includedRepos = ""
    @AppStorage(PRDeckDefaultsKey.zoomStep) private var zoomStep = 0
    @AppStorage(PRDeckDefaultsKey.showRepoAvatar) private var showRepoAvatar = true
    @AppStorage(PRDeckDefaultsKey.themePalette) private var themePaletteRaw = PRDeckPalette.appleBetter.rawValue
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var keyMonitor: KeyEventMonitor?
    @State private var isRepoFilterPresented = false
    @State private var repoFilterSearchText = ""
    @State private var toast: Toast?
    @State private var measuredHeights: [String: CGFloat] = [:]

    private enum RepoFilterMode: String {
        case exclude
        case include
    }

    private struct Toast: Identifiable {
        let id = UUID()
        let message: String
    }

    private var repoFilterMode: RepoFilterMode {
        RepoFilterMode(rawValue: repoFilterModeRaw) ?? .exclude
    }

    private var computedZoomScale: CGFloat {
        let clamped = max(-3, min(6, zoomStep))
        return pow(1.12, CGFloat(clamped))
    }

    private var titlebarHeight: CGFloat { 28 }

    private var themePalette: PRDeckPalette {
        PRDeckPalette(rawValue: themePaletteRaw) ?? .appleBetter
    }

    private var theme: PRDeckTheme {
        PRDeckTheme(palette: themePalette)
    }

    private var excludedRepoSet: Set<String> {
        let normalized = excludedRepos
            .replacingOccurrences(of: "\n", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Set(normalized)
    }

    private var includedRepoSet: Set<String> {
        let normalized = includedRepos
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

    private func setIncludedRepoSet(_ set: Set<String>) {
        includedRepos = set
            .map { $0.lowercased() }
            .sorted()
            .joined(separator: "\n")
    }

    private var availableRepos: [String] {
        var byLower: [String: String] = [:]

        for name in dataController.items.map(\.repository.nameWithOwner) {
            byLower[name.lowercased()] = name
        }

        for saved in excludedRepoSet.union(includedRepoSet) {
            if byLower[saved] == nil {
                byLower[saved] = saved
            }
        }

        return byLower.values.sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private var visibleReposForFiltering: [String] {
        let q = repoFilterSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return availableRepos }
        return availableRepos.filter { $0.lowercased().contains(q) }
    }

    private var visibleItems: [PRItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = dataController.items.filter { item in
            let repo = item.repository.nameWithOwner.lowercased()
            switch repoFilterMode {
            case .exclude:
                if excludedRepoSet.contains(repo) { return false }
            case .include:
                if !includedRepoSet.isEmpty, !includedRepoSet.contains(repo) { return false }
            }
            if !showAll, !item.needsAttention { return false }
            if q.isEmpty { return true }

            let needle = q.lowercased()
            if item.repository.nameWithOwner.lowercased().contains(needle) { return true }
            if item.title.lowercased().contains(needle) { return true }
            if String(item.number).contains(needle) { return true }
            return false
        }

        return filtered.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            if lhs.repository.nameWithOwner != rhs.repository.nameWithOwner {
                return lhs.repository.nameWithOwner.localizedCaseInsensitiveCompare(rhs.repository.nameWithOwner) == .orderedAscending
            }
            if lhs.number != rhs.number { return lhs.number > rhs.number }
            return lhs.id < rhs.id
        }
    }

    private var selectionBinding: Binding<PRItem.ID?> {
        Binding(
            get: { dataController.selectedId },
            set: { newValue in
                DispatchQueue.main.async {
                    dataController.selectedId = newValue
                }
            }
        )
    }

    private var needsAttentionCount: Int {
        dataController.items.filter { $0.needsAttention }.count
    }

    private var allCount: Int {
        dataController.items.count
    }

    private var isRepoFilterActive: Bool {
        switch repoFilterMode {
        case .exclude:
            return !excludedRepoSet.isEmpty
        case .include:
            return !includedRepoSet.isEmpty
        }
    }

    private var repoFilterActiveCount: Int {
        switch repoFilterMode {
        case .exclude:
            excludedRepoSet.count
        case .include:
            includedRepoSet.count
        }
    }

    private var repoFilterHelp: String {
        guard isRepoFilterActive else { return "Filter repositories" }
        let modeLabel = repoFilterMode == .exclude ? "excluded" : "included"
        return "Filter repositories (\(repoFilterActiveCount) \(modeLabel))"
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .prdeckMeasureHeight("topBar")
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)

            if let error = dataController.lastError {
                errorBanner(error)
                    .prdeckMeasureHeight("errorBanner")
            }

            if isRepoFilterPresented {
                filtersView
            } else {
                list
            }
        }
        .padding(.top, titlebarHeight)
        .background(alignment: .top) {
            Rectangle()
                .fill(theme.surface)
                .frame(height: titlebarHeight)
        }
        .background(theme.bg)
        .background(WindowAutoSizer(desiredContentHeight: desiredContentHeight).frame(width: 0, height: 0))
        .onAppear {
            migrateRepoFilterModeIfNeeded()
            installKeyMonitor()
        }
        .onDisappear { keyMonitor?.stop() }
        .onChange(of: isRepoFilterPresented) { _, newValue in
            if newValue { searchFocused = false }
        }
        .environment(\.prdeckTheme, theme)
        .environment(\.prdeckZoomScale, computedZoomScale)
        .tint(theme.accent)
        .preferredColorScheme(.dark)
        .onPreferenceChange(PRDeckViewHeightPreferenceKey.self) { newValues in
            measuredHeights.merge(newValues, uniquingKeysWith: { _, new in new })
        }
        .overlay(alignment: .bottom) {
            if let toast {
                toastView(toast.message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 12)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: toast?.id)
    }

    private var desiredContentHeight: CGFloat? {
        let topBarHeight = measuredHeights["topBar"] ?? 0
        guard topBarHeight > 0 else { return nil }

        let errorBannerHeight = dataController.lastError == nil ? 0 : (measuredHeights["errorBanner"] ?? 0)
        let dividerHeight: CGFloat = 1

        // Matches `PRRowView`'s minimum row height; List chrome is an approximation for inset style padding.
        let rowHeight = 52 * computedZoomScale
        let listChrome: CGFloat = 44
        let visibleCount = visibleItems.count
        let rowsHeight = rowHeight * CGFloat(max(visibleCount, 1))

        return titlebarHeight + topBarHeight + dividerHeight + errorBannerHeight + listChrome + rowsHeight
    }

    private func migrateRepoFilterModeIfNeeded() {
        if UserDefaults.standard.object(forKey: PRDeckDefaultsKey.repoFilterMode) != nil { return }

        if !excludedRepoSet.isEmpty {
            repoFilterModeRaw = RepoFilterMode.exclude.rawValue
        } else if !includedRepoSet.isEmpty {
            repoFilterModeRaw = RepoFilterMode.include.rawValue
        } else {
            repoFilterModeRaw = RepoFilterMode.exclude.rawValue
        }
    }

    private var topBar: some View {
        Group {
            if isRepoFilterPresented {
                FiltersHeaderBarView(
                    theme: theme,
                    zoomScale: computedZoomScale,
                    onBack: { isRepoFilterPresented = false }
                )
            } else {
                HeaderBarView(
                    theme: theme,
                    zoomScale: computedZoomScale,
                    searchText: $searchText,
                    searchFocused: $searchFocused,
                    isRepoFilterPresented: $isRepoFilterPresented,
                    isRepoFilterActive: isRepoFilterActive,
                    repoFilterActiveCount: repoFilterActiveCount,
                    repoFilterHelp: repoFilterHelp
                )
            }
        }
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 8) {
            Text(error)
                .lineLimit(2)
                .font(.system(size: 11 * computedZoomScale))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Button("Retry") { Task { await dataController.refresh(reloadRepos: true) } }
                .controlSize(.small)
                .prdeckInteractiveCursor()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.danger.opacity(0.12))
    }

    private var list: some View {
        List(visibleItems, selection: selectionBinding) { item in
            PRRowView(
                item: item,
                isRefreshing: dataController.isRefreshing,
                isSelected: item.id == dataController.selectedId,
                onCopyPRURL: { copyToPasteboard($0); showToast("Copied PR link") },
                onCopyCIURL: { copyToPasteboard($0); showToast("Copied CI link") }
            )
                .tag(item.id)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(theme.surface)
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
            case "f":
                guard !isRepoFilterPresented else { return false }
                searchFocused = true
                return true
            case "=", "+":
                zoomStep = min(6, zoomStep + 1)
                return true
            case "-":
                zoomStep = max(-3, zoomStep - 1)
                return true
            case "0":
                zoomStep = 0
                return true
            case "r":
                Task { await dataController.refresh(reloadRepos: true) }
                return true
            default:
                break
            }
        }

        let hasNonShiftModifiers = flags.contains(.command) || flags.contains(.control) || flags.contains(.option) || flags.contains(.function)
        if hasNonShiftModifiers { return false }

        if isRepoFilterPresented, key == "\u{1b}" { // escape
            isRepoFilterPresented = false
            return true
        }

        if isTextInputActive() {
            if searchFocused, key == "\u{1b}" { // escape
                searchFocused = false
                return true
            }
            return false
        }

        if isRepoFilterPresented {
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
            Task { await dataController.refresh(reloadRepos: true) }
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

    private func isTextInputActive() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }

        if let textView = responder as? NSTextView {
            return textView.isFieldEditor || textView.isEditable
        }

        return responder is NSTextField
    }

    private func copyToPasteboard(_ url: URL) {
        copyToPasteboard(url.absoluteString)
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func showToast(_ message: String) {
        let toast = Toast(message: message)
        self.toast = toast

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.25))
            if self.toast?.id == toast.id {
                self.toast = nil
            }
        }
    }

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12 * computedZoomScale, weight: .medium))
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.elevated, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1)
            )
            .shadow(color: theme.shadow, radius: 8, x: 0, y: 4)
            .padding(.horizontal, 12)
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

    private var filtersView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16 * computedZoomScale) {
                filtersPRScopeCard

                filtersReposCard

                filtersAppearanceCard
            }
            .padding(.horizontal, filtersOuterPaddingX)
            .padding(.vertical, filtersOuterPaddingY)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.surface)
    }

    private var filtersOuterPaddingX: CGFloat { 20 * computedZoomScale }
    private var filtersOuterPaddingY: CGFloat { 16 * computedZoomScale }

    private var filtersPRScopeCard: some View {
        filterCard {
            VStack(alignment: .leading, spacing: 12 * computedZoomScale) {
                Text("Pull Requests")
                    .font(.system(size: 13.5 * computedZoomScale, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                PRDeckSegmentedControl(
                    theme: theme,
                    zoomScale: computedZoomScale,
                    segments: [
                        .init("attention", title: "Needs attention (\(needsAttentionCount))"),
                        .init("all", title: "All (\(allCount))"),
                    ],
                    selection: Binding(
                    get: { showAll ? "all" : "attention" },
                    set: { showAll = $0 == "all" }
                    )
                )
            }
        }
    }

    private var filtersReposCard: some View {
        filterCard {
            VStack(alignment: .leading, spacing: 12 * computedZoomScale) {
                HStack(alignment: .center, spacing: 10 * computedZoomScale) {
                    Text("Repositories")
                        .font(.system(size: 13.5 * computedZoomScale, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    if isRepoFilterActive {
                        repoFilterPill
                    }
                }

                PRDeckSegmentedControl(
                    theme: theme,
                    zoomScale: computedZoomScale,
                    segments: [
                        .init(RepoFilterMode.exclude.rawValue, title: "Exclude"),
                        .init(RepoFilterMode.include.rawValue, title: "Include"),
                    ],
                    selection: $repoFilterModeRaw
                )
                .frame(width: 240)

                filterSearchField

                HStack(spacing: 8 * computedZoomScale) {
                    Button("Select All") {
                        switch repoFilterMode {
                        case .exclude:
                            var set = excludedRepoSet
                            for repo in visibleReposForFiltering { set.insert(repo.lowercased()) }
                            setExcludedRepoSet(set)
                        case .include:
                            var set = includedRepoSet
                            for repo in visibleReposForFiltering { set.insert(repo.lowercased()) }
                            setIncludedRepoSet(set)
                        }
                    }
                    .controlSize(.small)
                    .prdeckInteractiveCursor()

                    Button("Clear") {
                        switch repoFilterMode {
                        case .exclude:
                            setExcludedRepoSet([])
                        case .include:
                            setIncludedRepoSet([])
                        }
                    }
                    .controlSize(.small)
                    .prdeckInteractiveCursor()

                    Spacer()
                }

                repoToggleList
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var filtersAppearanceCard: some View {
        filterCard {
            VStack(alignment: .leading, spacing: 12 * computedZoomScale) {
                Text("Appearance")
                    .font(.system(size: 13.5 * computedZoomScale, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Toggle("Show repo/org logo", isOn: $showRepoAvatar)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .prdeckToolTip("Shows the repository owner avatar on each PR row")
                    .prdeckInteractiveCursor()
            }
        }
    }

    private func filterCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14 * computedZoomScale, style: .continuous)
                    .fill(theme.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14 * computedZoomScale, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            )
    }

    private var repoFilterPill: some View {
        let mode = repoFilterMode == .exclude ? "excluded" : "included"
        let label = "Repo: \(repoFilterActiveCount) \(mode)"

        return Button {
            switch repoFilterMode {
            case .exclude: setExcludedRepoSet([])
            case .include: setIncludedRepoSet([])
            }
        } label: {
            HStack(spacing: 6 * computedZoomScale) {
                Text(label)
                    .font(.system(size: 11.5 * computedZoomScale, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)

                Image(systemName: "xmark")
                    .font(.system(size: 9 * computedZoomScale, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 18 * computedZoomScale, height: 18 * computedZoomScale)
                    .background(theme.surface, in: Circle())
                    .overlay(Circle().stroke(theme.border, lineWidth: 1))
            }
            .padding(.leading, 10 * computedZoomScale)
            .padding(.trailing, 6 * computedZoomScale)
            .frame(height: 26 * computedZoomScale)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.surface)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .prdeckInteractiveCursor()
    }

    private var filterSearchField: some View {
        HStack(spacing: 6 * computedZoomScale) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12.5 * computedZoomScale))
                .foregroundStyle(theme.textDisabled)

            TextField("Filter repos…", text: $repoFilterSearchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5 * computedZoomScale))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 10 * computedZoomScale)
        .frame(height: 32 * computedZoomScale)
        .background(
            RoundedRectangle(cornerRadius: 12 * computedZoomScale, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12 * computedZoomScale, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
        )
    }

    private var repoToggleList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if visibleReposForFiltering.isEmpty {
                Text("No repositories match your search.")
                    .font(.system(size: 12 * computedZoomScale, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.vertical, 12 * computedZoomScale)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleReposForFiltering, id: \.self) { repo in
                        Toggle(repo, isOn: repoToggleBinding(for: repo))
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12.5 * computedZoomScale, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                            .padding(.vertical, 7 * computedZoomScale)
                            .padding(.horizontal, 10 * computedZoomScale)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .prdeckInteractiveCursor()

                        if repo != visibleReposForFiltering.last {
                            Rectangle()
                                .fill(theme.divider)
                                .frame(height: 1)
                                .padding(.leading, 10 * computedZoomScale)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12 * computedZoomScale, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12 * computedZoomScale, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
        )
    }

    private func repoToggleBinding(for repo: String) -> Binding<Bool> {
        Binding(
            get: {
                switch repoFilterMode {
                case .exclude:
                    return excludedRepoSet.contains(repo.lowercased())
                case .include:
                    return includedRepoSet.contains(repo.lowercased())
                }
            },
            set: { isOn in
                switch repoFilterMode {
                case .exclude:
                    var set = excludedRepoSet
                    if isOn { set.insert(repo.lowercased()) } else { set.remove(repo.lowercased()) }
                    setExcludedRepoSet(set)
                case .include:
                    var set = includedRepoSet
                    if isOn { set.insert(repo.lowercased()) } else { set.remove(repo.lowercased()) }
                    setIncludedRepoSet(set)
                }
            }
        )
    }
}
