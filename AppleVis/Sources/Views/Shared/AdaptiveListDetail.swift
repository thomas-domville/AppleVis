import SwiftUI

// MARK: - Adaptive list and detail (2026-10-06)
//
// On a wide window (iPad, a wide Stage Manager window, an open iPhone Duo),
// a list can keep itself on screen and show the item you choose beside it.
// On a narrow one (any iPhone, iPad Split View at a third, a closed Duo),
// nothing changes: the row pushes the item exactly as it always has.
//
// Why not NavigationSplitView: the lists that benefit (Forums, Apps,
// Podcasts) are pushed onto Discover's NavigationStack, and a split view
// only works as the root of a window or tab. Making it the root would mean
// replacing Discover's stack and its documented VoiceOver focus handling,
// or nesting stacks, which Settings' comments record breaking navigation.
// So the list screen lays out its own two panes inside the stack instead,
// and anything opened from inside the detail pane still pushes onto the
// same stack as before.
//
// Wide or narrow is decided from the size class and the width actually
// available, never from the device: an iPad at a third of the screen is
// narrow, an open iPhone Duo is wide. Part of the Adaptive Experience
// upgrade, phase 1 (docs/IPADOS_UPGRADE_IMPLEMENTATION_SPEC.md).

/// A post chosen in a list: which kind, which one, and whether to open it at
/// its first new comment. Codable so a later phase can restore it.
struct ContentSelection: Hashable, Codable {
    let kind: ContentKind
    let id: String
    var focusFirstNewComment = false
}

/// Whether a list has room to show its item beside it. Kept as a plain
/// function so it can be tested without a window.
enum AdaptiveLayout {
    /// Below this, the list and the item each get too little room to read
    /// comfortably at large text sizes, even when the size class is regular
    /// (a half-screen iPad in Split View reports regular on the largest
    /// iPads). Chosen to keep both panes readable at large Dynamic Type.
    static let minimumSplitWidth: CGFloat = 700

    static func showsDetailBeside(horizontalSizeClass: UserInterfaceSizeClass?, width: CGFloat) -> Bool {
        horizontalSizeClass == .regular && width >= minimumSplitWidth
    }

    /// The list pane's width: about a third of the window, kept between
    /// what a row needs and what still leaves the item most of the room.
    static func listWidth(for width: CGFloat) -> CGFloat {
        min(max(width * 0.36, 320), 440)
    }
}

// MARK: - What rows and stacks are offered

/// Offered to rows inside a wide list: choosing one shows it beside the
/// list instead of pushing it. Rows without this push as they always have.
/// `title` is what VoiceOver says was shown.
struct SelectInDetailAction {
    let selectedID: String?
    let select: (ContentSelection, String) -> Void

    func callAsFunction(_ selection: ContentSelection, title: String) { select(selection, title) }
    func isSelected(_ id: String) -> Bool { selectedID == id }
}

/// Offered to a detail screen beside its list: closes the pane, for
/// instance after the item is deleted. A pushed screen uses `dismiss`
/// instead; calling `dismiss` in the pane would close the whole list.
struct CloseDetailPaneAction {
    let close: () -> Void
    func callAsFunction() { close() }
}

/// Offered by every navigation stack (AppNavigationStack, Discover): pushes
/// a post onto that stack. Used when a wide list becomes narrow with an item
/// showing, so the item stays on screen as a normal pushed screen with Back
/// to the list, instead of disappearing.
struct PushContentAction {
    let push: (ContentSelection) -> Void
    func callAsFunction(_ selection: ContentSelection) { push(selection) }
}

private struct SelectInDetailKey: EnvironmentKey {
    static let defaultValue: SelectInDetailAction? = nil
}

private struct PushContentKey: EnvironmentKey {
    static let defaultValue: PushContentAction? = nil
}

private struct IsInDetailPaneKey: EnvironmentKey {
    static let defaultValue = false
}

private struct DetailFocusRequestKey: EnvironmentKey {
    static let defaultValue = 0
}

private struct CloseDetailPaneKey: EnvironmentKey {
    static let defaultValue: CloseDetailPaneAction? = nil
}

extension EnvironmentValues {
    var selectInDetail: SelectInDetailAction? {
        get { self[SelectInDetailKey.self] }
        set { self[SelectInDetailKey.self] = newValue }
    }

    var pushContent: PushContentAction? {
        get { self[PushContentKey.self] }
        set { self[PushContentKey.self] = newValue }
    }

    /// True for a detail screen shown beside its list. Detail screens use it
    /// to leave VoiceOver where it is when they appear, since choosing a row
    /// mustn't pull focus away from the list.
    var isInDetailPane: Bool {
        get { self[IsInDetailPaneKey.self] }
        set { self[IsInDetailPaneKey.self] = newValue }
    }

    /// Goes up by one each time someone asks to move to the item beside the
    /// list (choosing the row that's already showing). Detail screens move
    /// VoiceOver to their title when it changes.
    var detailFocusRequest: Int {
        get { self[DetailFocusRequestKey.self] }
        set { self[DetailFocusRequestKey.self] = newValue }
    }

    var closeDetailPane: CloseDetailPaneAction? {
        get { self[CloseDetailPaneKey.self] }
        set { self[CloseDetailPaneKey.self] = newValue }
    }
}

extension View {
    /// Lets a stack open a ContentSelection pushed by `pushContent`.
    func contentSelectionDestination() -> some View {
        navigationDestination(for: ContentSelection.self) { selection in
            ContentDetailDestination(kind: selection.kind, id: selection.id,
                                     focusFirstNewComment: selection.focusFirstNewComment)
        }
    }
}

// MARK: - The container

/// A list that, on a wide window, shows the chosen item beside it.
///
/// - Narrow: shows `list` only, with no `selectInDetail` offered, so rows
///   behave exactly as they do today.
/// - Wide: list on the leading side, the selection (or `placeholder`) on
///   the trailing side. Rows are offered `selectInDetail`.
/// - Wide to narrow with something showing: the item is pushed onto the
///   surrounding stack, so it stays on screen with Back to the list.
struct AdaptiveListDetail<ListContent: View, Detail: View>: View {
    @Binding var selection: ContentSelection?
    let placeholder: LocalizedStringKey
    let placeholderSystemImage: String
    /// Called when the item beside the list closes itself (after it's
    /// deleted), so the list can drop it and move VoiceOver to a neighbor.
    var onDetailClosed: ((ContentSelection) -> Void)?
    /// False while the screen is showing something that isn't a list of
    /// items, such as the App Directory's category picker, where an empty
    /// pane beside it would only be in the way.
    var isEnabled: Bool
    let list: () -> ListContent
    let detail: (ContentSelection) -> Detail

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.pushContent) private var pushContent
    /// The stack's own Jump to First New Comment, used on a narrow window.
    @Environment(\.openAtFirstNewComment) private var inheritedOpenAtFirstNewComment
    @State private var width: CGFloat = 0
    @State private var focusRequest = 0

    init(selection: Binding<ContentSelection?>,
         placeholder: LocalizedStringKey,
         placeholderSystemImage: String,
         onDetailClosed: ((ContentSelection) -> Void)? = nil,
         isEnabled: Bool = true,
         @ViewBuilder list: @escaping () -> ListContent,
         @ViewBuilder detail: @escaping (ContentSelection) -> Detail) {
        _selection = selection
        self.placeholder = placeholder
        self.placeholderSystemImage = placeholderSystemImage
        self.onDetailClosed = onDetailClosed
        self.isEnabled = isEnabled
        self.list = list
        self.detail = detail
    }

    /// Choosing a row shows it beside the list and leaves VoiceOver on the
    /// row, saying what was shown. Choosing the row that's already showing
    /// moves VoiceOver to it, the same as reaching it with the Headings
    /// rotor. The adaptive spec requires that a selection never pulls focus
    /// away from the list on its own.
    private func select(_ new: ContentSelection, title: String) {
        if selection?.id == new.id, selection?.kind == new.kind, !new.focusFirstNewComment {
            focusRequest += 1
            return
        }
        selection = new
        if !new.focusFirstNewComment, !title.isEmpty {
            UIAccessibility.post(notification: .announcement, argument: String(localized: "\(title), shown beside the list."))
        }
    }

    private var isWide: Bool {
        AdaptiveLayout.showsDetailBeside(horizontalSizeClass: horizontalSizeClass, width: width)
    }

    private var showsDetailBeside: Bool { isEnabled && isWide }

    var body: some View {
        // One layout for both widths, with the list always in the same
        // place: going between narrow and wide only adds or removes the
        // pane beside it, so the list keeps its scroll position and nothing
        // in it reloads (Adaptive Experience, phase 17).
        HStack(spacing: 0) {
            list()
                .frame(width: showsDetailBeside ? AdaptiveLayout.listWidth(for: width) : nil)
                .frame(maxWidth: showsDetailBeside ? nil : .infinity)
                .environment(\.selectInDetail, showsDetailBeside
                    ? SelectInDetailAction(selectedID: selection?.id) { select($0, title: $1) }
                    : nil)
                // Jump to First New Comment opens beside the list too, and
                // goes straight to that comment, since the person asked for
                // it. On a narrow window it pushes, as before.
                .environment(\.openAtFirstNewComment, showsDetailBeside
                    ? OpenAtFirstNewCommentAction { target in
                        select(ContentSelection(kind: target.kind, id: target.id, focusFirstNewComment: true), title: "")
                    }
                    : inheritedOpenAtFirstNewComment)
            if showsDetailBeside {
                Divider()
                Group {
                    if let selection {
                        detail(selection)
                            // A new item gets a fresh screen, so its own
                            // loading and focus state start over.
                            .id(selection)
                            .environment(\.isInDetailPane, true)
                            .environment(\.detailFocusRequest, focusRequest)
                            .environment(\.closeDetailPane, CloseDetailPaneAction {
                                let closed = selection
                                self.selection = nil
                                onDetailClosed?(closed)
                            })
                    } else {
                        DetailPlaceholderView(message: placeholder, systemImage: placeholderSystemImage)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: isWide) { wasWide, nowWide in
            // Wide to narrow with an item showing: keep it on screen.
            guard isEnabled, wasWide, !nowWide, let shown = selection else { return }
            selection = nil
            pushContent?(shown)
        }
        // Leaving the list (clearing a search, say) closes what was beside
        // it rather than pushing it: the person moved on from that list.
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { selection = nil }
        }
    }
}

/// Shown beside a wide list until something is chosen. Plain text, read
/// once by VoiceOver if someone moves to it; never focused automatically.
struct DetailPlaceholderView: View {
    let message: LocalizedStringKey
    let systemImage: String
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(preferences.colors.textSecondary)
                .accessibilityHidden(true)
            Text(message)
                .font(.body)
                .foregroundStyle(preferences.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(preferences.colors.background)
    }
}

// MARK: - Rows

/// A row's link: pushes `value` on a narrow window, exactly as before, and
/// on a wide one shows the item beside the list, marked Selected for
/// VoiceOver and tinted for sight.
struct AdaptiveRowLink<Value: Hashable, RowLabel: View>: View {
    let value: Value
    let selection: ContentSelection
    let title: String
    @ViewBuilder let label: () -> RowLabel

    @Environment(\.selectInDetail) private var selectInDetail
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        if let selectInDetail {
            let isSelected = selectInDetail.isSelected(selection.id)
            Button {
                selectInDetail(selection, title: title)
            } label: {
                label()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)
            .background(isSelected ? preferences.colors.accent.opacity(0.15) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityHint(isSelected
                ? String(localized: "Moves to it, beside the list.")
                : String(localized: "Shows it beside the list."))
        } else {
            NavigationLink(value: value) { label() }
        }
    }
}
