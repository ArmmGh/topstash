import SwiftUI

/// The content of the notch panel: a black `NotchShape` that grows out of the notch, with the
/// mode's content on it. Only this SwiftUI content animates; the window frame stays fixed.
struct PanelView: View {
    let appModel: AppModel
    let actions: PanelActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var panel: PanelModel { appModel.panel }
    private var isOpen: Bool { panel.mode != .closed }

    var body: some View {
        ZStack(alignment: .top) {
            backing
            content
        }
        .frame(width: PanelLayout.windowSize.width, height: PanelLayout.windowSize.height, alignment: .top)
    }

    // MARK: - Shape

    private var shapeSize: CGSize { appModel.shapeSize }

    private var topCornerRadius: CGFloat {
        isOpen ? PanelLayout.topCornerRadius : PanelLayout.collapsedTopCornerRadius
    }

    private var bottomCornerRadius: CGFloat {
        isOpen ? PanelLayout.bottomCornerRadius : PanelLayout.collapsedBottomCornerRadius
    }

    /// The shape at `shapeSize`, growing and shrinking with the mode's spring. Hangs from the top
    /// center of whatever it fills.
    private var animatedShape: some View {
        NotchShape(bodySize: shapeSize, topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
            .animation(Motion.shape(expanding: isOpen, reduceMotion: reduceMotion), value: shapeSize)
            .animation(Motion.shape(expanding: isOpen, reduceMotion: reduceMotion), value: isOpen)
    }

    /// An oversized black backing masked by the shape, so a spring's overshoot never shows a gap.
    /// The shadow is drawn here; the window has none.
    private var backing: some View {
        Color.black
            .mask(alignment: .top) {
                // Fills the backing; the shape positions its body itself (see `NotchShape`).
                animatedShape
                    // The gulp when a saved card flies into the notch. None with Reduce Motion.
                    // None in search mode either, where no card flies (the shortcut shows a status there).
                    .phaseAnimator([false, true], trigger: reduceMotion ? 0 : panel.saveCount) { shape, gulping in
                        shape.scaleEffect(gulping && panel.mode != .search ? Motion.gulpScale : 1, anchor: .top)
                    } animation: { gulping in
                        gulping ? Motion.gulp.delay(Motion.gulpDelay) : Motion.gulp
                    }
            }
            .shadow(
                color: .black.opacity(PanelLayout.shadowOpacity),
                radius: PanelLayout.shadowRadius,
                y: PanelLayout.shadowOffsetY
            )
            .allowsHitTesting(false)
    }

    // MARK: - Content

    /// Each mode's content comes in after the shape starts growing and leaves before it collapses.
    /// The header stays while switching between the list and search.
    private var content: some View {
        let results = panel.mode == .search ? appModel.searchResults : []
        return ZStack(alignment: .top) {
            switch panel.mode {
            case .closed:
                EmptyView()
            case .open, .feedback:
                // One view for both, so going from the shortcut's feedback to `.open` keeps the card
                // in place while the list comes in.
                recentContent
                    .transition(Motion.content(reduceMotion: reduceMotion))
            case .search:
                SearchView(appModel: appModel, actions: actions, results: results)
                    .padding(.top, panel.headerHeight + PanelLayout.sectionSpacing)
                    .padding(.bottom, PanelLayout.inset)
                    .frame(width: PanelLayout.panelWidth, height: shapeSize.height, alignment: .top)
                    // Rows that arrive while the shape is still growing to fit them show only inside it.
                    .mask(alignment: .top) { animatedShape }
                    .transition(Motion.content(reduceMotion: reduceMotion))
            }
            if isOpen {
                PanelHeader(
                    panel: panel,
                    actions: actions,
                    total: appModel.store.notes.count,
                    matches: panel.mode == .search && !panel.query.isEmpty ? results.count : nil,
                    isSearch: panel.mode == .search
                )
                .frame(width: PanelLayout.panelWidth)
                // The shortcut's feedback shows only the card; the header's band stays clear.
                .opacity(panel.showsOnlySaveCard ? 0 : 1)
                .allowsHitTesting(!panel.showsOnlySaveCard)
                .accessibilityHidden(panel.showsOnlySaveCard)
                .transition(Motion.content(reduceMotion: reduceMotion))
            }
        }
        .animation(isOpen ? Motion.contentIn : Motion.contentOut, value: panel.mode)
        .allowsHitTesting(isOpen)
    }

    private var recentContent: some View {
        VStack(spacing: PanelLayout.sectionSpacing) {
            SaveCardSlot(panel: panel) {
                // Shows this save's result, not the state shown before the click: the clipboard can change in between.
                appModel.showSaveResult(appModel.saveClipboard())
            }
            // The shortcut's feedback shows only the card.
            if !panel.showsOnlySaveCard {
                recentList
            }
        }
        .padding(.top, panel.headerHeight + PanelLayout.sectionSpacing)
        .padding([.horizontal, .bottom], PanelLayout.inset)
        .frame(width: PanelLayout.panelWidth, height: shapeSize.height, alignment: .top)
        // When the card's height changes, the list moves with the shape's edge.
        .animation(Motion.shape(expanding: true, reduceMotion: reduceMotion), value: panel.saveCardHeight)
    }

    private var recentList: some View {
        NoteList(
            appModel: appModel,
            actions: actions,
            notes: appModel.store.recent(limit: PanelLayout.recentCount),
            emptyText: "No notes yet"
        )
    }
}
