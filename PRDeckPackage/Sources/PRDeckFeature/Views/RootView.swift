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
    @State private var refreshIndicatorTask: Task<Void, Never>?
    @State private var showRefreshIndicators = false
    @State private var isThemeMenuHovered = false

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

    private var sizingItemCount: Int {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return visibleItems.count }

        return dataController.items.reduce(into: 0) { count, item in
            let repo = item.repository.nameWithOwner.lowercased()
            switch repoFilterMode {
            case .exclude:
                if excludedRepoSet.contains(repo) { return }
            case .include:
                if !includedRepoSet.isEmpty, !includedRepoSet.contains(repo) { return }
            }
            if !showAll, !item.needsAttention { return }
            count += 1
        }
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
        .background(theme.bg)
        .background(WindowAutoSizer(desiredContentHeight: desiredContentHeight).frame(width: 0, height: 0))
        .onAppear {
            migrateRepoFilterModeIfNeeded()
            installKeyMonitor()
        }
        .onDisappear {
            refreshIndicatorTask?.cancel()
            refreshIndicatorTask = nil
            keyMonitor?.stop()
        }
        .onChange(of: isRepoFilterPresented) { _, newValue in
            if newValue { searchFocused = false }
        }
        .onChange(of: dataController.isRefreshing) { _, isRefreshing in
            refreshIndicatorTask?.cancel()
            refreshIndicatorTask = nil

            if isRefreshing {
                refreshIndicatorTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    guard !Task.isCancelled, dataController.isRefreshing else { return }
                    showRefreshIndicators = true
                }
            } else {
                showRefreshIndicators = false
            }
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

        let rowHeight = PRDeckLayout.rowHeight * computedZoomScale
        let visibleCount = sizingItemCount
        let rowsHeight = rowHeight * CGFloat(max(visibleCount, 1))

        let rowSpacing = PRDeckLayout.rowSpacing * computedZoomScale
        let interRowSpacing = rowSpacing * CGFloat(max(visibleCount - 1, 0))

        let listPaddingY = PRDeckLayout.sectionPadding * computedZoomScale
        let listChrome = (listPaddingY * 2) + interRowSpacing

        return topBarHeight + dividerHeight + errorBannerHeight + listChrome + rowsHeight
    }

    // Scaled layout values using unified system
    // Note: listInset and scrollGutter are NOT scaled - they're window chrome
    private var contentPadding: CGFloat { PRDeckLayout.contentPadding * computedZoomScale }

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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: PRDeckLayout.rowSpacing * computedZoomScale) {
                    ForEach(visibleItems) { item in
                        PRRowView(
                            item: item,
                            isRefreshing: showRefreshIndicators,
                            isSelected: item.id == dataController.selectedId,
                            onCopyPRURL: { copyToPasteboard($0); showToast("Copied PR link") },
                            onCopyCIURL: { copyToPasteboard($0); showToast("Copied CI link") },
                            onSelect: { dataController.selectedId = item.id }
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal, PRDeckLayout.listInset + PRDeckLayout.scrollGutter)
                .padding(.vertical, PRDeckLayout.sectionPadding * computedZoomScale)
            }
            .background(theme.surface)
            .onChange(of: dataController.selectedId) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
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
            VStack(alignment: .leading, spacing: 12 * computedZoomScale) {
                filtersPRScopeCard

                filtersReposCard

                filtersAppearanceCard
            }
            .padding(.horizontal, PRDeckLayout.listInset + PRDeckLayout.scrollGutter)
            .padding(.vertical, 12 * computedZoomScale)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.surface)
    }

    private var filtersPRScopeCard: some View {
        filterCard {
            VStack(alignment: .leading, spacing: 10 * computedZoomScale) {
                Text("Pull Requests")
                    .font(.system(size: 12 * computedZoomScale, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

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
            VStack(alignment: .leading, spacing: 10 * computedZoomScale) {
                HStack(alignment: .center, spacing: 8 * computedZoomScale) {
                    Text("Repositories")
                        .font(.system(size: 12 * computedZoomScale, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

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

                filterSearchField

                HStack(spacing: 8 * computedZoomScale) {
                    filterActionButton("Select All") {
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

                    filterActionButton("Clear") {
                        switch repoFilterMode {
                        case .exclude:
                            setExcludedRepoSet([])
                        case .include:
                            setIncludedRepoSet([])
                        }
                    }

                    Spacer()
                }

                repoToggleList
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func filterActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11 * computedZoomScale, weight: .medium))
                .foregroundStyle(theme.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10 * computedZoomScale)
        .padding(.vertical, 5 * computedZoomScale)
        .background(
            RoundedRectangle(cornerRadius: 6 * computedZoomScale, style: .continuous)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6 * computedZoomScale, style: .continuous)
                .stroke(theme.border.opacity(0.5), lineWidth: 1)
        )
        .prdeckInteractiveCursor()
    }

    private var filtersAppearanceCard: some View {
        filterCard {
            VStack(alignment: .leading, spacing: 10 * computedZoomScale) {
                Text("Appearance")
                    .font(.system(size: 12 * computedZoomScale, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack(alignment: .center, spacing: 10 * computedZoomScale) {
                    Text("Theme")
                        .font(.system(size: 12.5 * computedZoomScale, weight: .medium))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    themeMenu
                }

                HStack(alignment: .center, spacing: 10 * computedZoomScale) {
                    Text("Show repo logo")
                        .font(.system(size: 12.5 * computedZoomScale, weight: .medium))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    Toggle("", isOn: $showRepoAvatar)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .prdeckInteractiveCursor()
                }
            }
        }
    }

    private var themeMenu: some View {
        Menu {
            ForEach(PRDeckPalette.allCases) { palette in
                Button {
                    themePaletteRaw = palette.rawValue
                } label: {
                    if palette.rawValue == themePaletteRaw {
                        Label(palette.displayName, systemImage: "checkmark")
                    } else {
                        Text(palette.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 6 * computedZoomScale) {
                Text(themePalette.displayName)
                    .font(.system(size: 11.5 * computedZoomScale, weight: .medium))
                    .foregroundStyle(theme.textPrimary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9 * computedZoomScale, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, 10 * computedZoomScale)
            .frame(height: 26 * computedZoomScale)
            .background(
                RoundedRectangle(cornerRadius: 6 * computedZoomScale, style: .continuous)
                    .fill(isThemeMenuHovered ? theme.rowHover : theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6 * computedZoomScale, style: .continuous)
                    .stroke(theme.border.opacity(0.5), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6 * computedZoomScale, style: .continuous))
            .onHover { isThemeMenuHovered = $0 }
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .controlSize(.small)
        .prdeckInteractiveCursor()
    }

    private func filterCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14 * computedZoomScale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12 * computedZoomScale, style: .continuous)
                    .fill(theme.surface2.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12 * computedZoomScale, style: .continuous)
                    .stroke(theme.border.opacity(0.4), lineWidth: 1)
            )
    }

    private var repoFilterPill: some View {
        let count = repoFilterActiveCount

        return Button {
            switch repoFilterMode {
            case .exclude: setExcludedRepoSet([])
            case .include: setIncludedRepoSet([])
            }
        } label: {
            HStack(spacing: 5 * computedZoomScale) {
                Text("\(count)")
                    .font(.system(size: 10 * computedZoomScale, weight: .semibold).monospacedDigit())
                    .foregroundStyle(theme.bg)
                    .frame(width: 16 * computedZoomScale, height: 16 * computedZoomScale)
                    .background(theme.accent, in: Circle())

                Image(systemName: "xmark")
                    .font(.system(size: 8 * computedZoomScale, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.leading, 4 * computedZoomScale)
            .padding(.trailing, 8 * computedZoomScale)
            .frame(height: 24 * computedZoomScale)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(theme.border.opacity(0.5), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .prdeckInteractiveCursor()
    }

    private var filterSearchField: some View {
        HStack(spacing: 8 * computedZoomScale) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11 * computedZoomScale, weight: .medium))
                .foregroundStyle(theme.textTertiary)

            TextField("Filter repos...", text: $repoFilterSearchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12 * computedZoomScale, weight: .medium))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 10 * computedZoomScale)
        .frame(height: 30 * computedZoomScale)
        .background(
            RoundedRectangle(cornerRadius: 8 * computedZoomScale, style: .continuous)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8 * computedZoomScale, style: .continuous)
                .stroke(theme.border.opacity(0.5), lineWidth: 1)
        )
    }

    private var repoToggleList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if visibleReposForFiltering.isEmpty {
                Text("No repositories match your search.")
                    .font(.system(size: 11 * computedZoomScale, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.vertical, 12 * computedZoomScale)
                    .padding(.horizontal, 10 * computedZoomScale)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleReposForFiltering, id: \.self) { repo in
                        Toggle(repo, isOn: repoToggleBinding(for: repo))
                            .toggleStyle(.checkbox)
                            .font(.system(size: 11.5 * computedZoomScale, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                            .padding(.vertical, 6 * computedZoomScale)
                            .padding(.horizontal, 10 * computedZoomScale)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .prdeckInteractiveCursor()

                        if repo != visibleReposForFiltering.last {
                            Rectangle()
                                .fill(theme.divider.opacity(0.5))
                                .frame(height: 1)
                                .padding(.leading, 10 * computedZoomScale)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8 * computedZoomScale, style: .continuous)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8 * computedZoomScale, style: .continuous)
                .stroke(theme.border.opacity(0.5), lineWidth: 1)
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
