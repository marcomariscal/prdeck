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
    @State private var hoveredAttentionSegment: AttentionSegment?

    private enum RepoFilterMode: String {
        case exclude
        case include
    }

    private struct Toast: Identifiable {
        let id = UUID()
        let message: String
    }

    private enum AttentionSegment: Hashable {
        case attention
        case all
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

            list
        }
        .padding(.top, titlebarHeight)
        .background(alignment: .top) {
            Rectangle()
                .fill(theme.surface2)
                .frame(height: titlebarHeight)
        }
        .background(theme.bg)
        .background(WindowAutoSizer(desiredContentHeight: desiredContentHeight).frame(width: 0, height: 0))
        .onAppear {
            migrateRepoFilterModeIfNeeded()
            installKeyMonitor()
        }
        .onDisappear { keyMonitor?.stop() }
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
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13 * computedZoomScale))
                    .foregroundStyle(theme.textDisabled)

                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .font(.system(size: 13 * computedZoomScale))
                    .foregroundStyle(theme.textPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(searchFocused ? theme.focusRing : theme.border, lineWidth: searchFocused ? 1.5 : 1)
                    )
            )
            .frame(maxWidth: 300)

            Spacer()

            attentionToggle

            Spacer()

            Button {
                isRepoFilterPresented = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 15 * computedZoomScale))
                    .foregroundStyle(isRepoFilterActive ? theme.textPrimary : theme.textSecondary)
            }
            .buttonStyle(.plain)
            .prdeckInteractiveCursor()
            .popover(isPresented: $isRepoFilterPresented, arrowEdge: .top) {
                repoFilterPopover
            }
            .help("Filter repositories")

            Button {
                Task { await dataController.refresh() }
            } label: {
                ZStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14 * computedZoomScale))
                        .foregroundStyle(theme.textSecondary)
                        .opacity(dataController.isRefreshing ? 0 : 1)

                    ProgressView()
                        .controlSize(.small)
                        .opacity(dataController.isRefreshing ? 1 : 0)
                }
                .frame(width: 18 * computedZoomScale, height: 18 * computedZoomScale)
            }
            .buttonStyle(.plain)
            .prdeckInteractiveCursor()
            .disabled(dataController.isRefreshing)
            .help(dataController.isRefreshing ? "Refreshing…" : "Refresh")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.surface2)
    }

    private var attentionToggle: some View {
        HStack(spacing: 0) {
            attentionToggleButton(
                segment: .attention,
                title: "Needs attention",
                count: needsAttentionCount,
                isOn: !showAll,
                action: { showAll = false }
            )

            attentionToggleButton(
                segment: .all,
                title: "All",
                count: allCount,
                isOn: showAll,
                action: { showAll = true }
            )
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .frame(width: 280)
        .animation(.easeInOut(duration: 0.14), value: showAll)
        .animation(.easeInOut(duration: 0.10), value: hoveredAttentionSegment)
    }

    private func attentionToggleButton(
        segment: AttentionSegment,
        title: String,
        count: Int,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredAttentionSegment == segment

        return Button(action: action) {
            (
                Text(title)
                    .foregroundStyle(isOn ? theme.textPrimary : theme.textSecondary)
                +
                Text(" (\(count))")
                    .monospacedDigit()
                    .foregroundStyle(isOn ? theme.textSecondary : theme.textTertiary)
            )
            .font(.system(size: 11.25 * computedZoomScale, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .allowsTightening(true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? theme.rowSelected : (isHovered ? theme.rowHover : .clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isOn ? theme.focusRing.opacity(0.8) : .clear, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .prdeckInteractiveCursor()
        .onHover { isHovering in
            if isHovering {
                hoveredAttentionSegment = segment
            } else if hoveredAttentionSegment == segment {
                hoveredAttentionSegment = nil
            }
        }
        .accessibilityLabel(Text("\(title), \(count)"))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 8) {
            Text(error)
                .lineLimit(2)
                .font(.system(size: 11 * computedZoomScale))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Button("Retry") { Task { await dataController.refresh() } }
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

        if isTextInputActive() {
            if searchFocused, key == "\u{1b}" { // escape
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

    private var repoFilterPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Repositories")
                .font(.headline)

            Picker("", selection: $repoFilterModeRaw) {
                Text("Exclude").tag(RepoFilterMode.exclude.rawValue)
                Text("Include").tag(RepoFilterMode.include.rawValue)
            }
            .pickerStyle(.segmented)
            .prdeckInteractiveCursor()
            .frame(width: 240)

            Toggle("Show repo/org logo", isOn: $showRepoAvatar)
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Shows the repository owner avatar on each PR row")
                .prdeckInteractiveCursor()

            TextField("Filter repos…", text: $repoFilterSearchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360)

            VStack(alignment: .leading, spacing: 6) {
                Text(repoFilterMode == .exclude ? "Hide repos" : "Show repos")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: 8) {
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

                List(visibleReposForFiltering, id: \.self) { repo in
                    Toggle(repo, isOn: .init(
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
                    ))
                    .toggleStyle(.checkbox)
                    .prdeckInteractiveCursor()
                }
                .frame(width: 380, height: 220)
            }

            HStack {
                Spacer()
                Button("Done") { isRepoFilterPresented = false }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.regular)
                    .prdeckInteractiveCursor()
            }
        }
        .padding(12)
    }
}
