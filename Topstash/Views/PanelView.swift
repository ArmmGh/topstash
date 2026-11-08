import SwiftUI

/// The content of the notch panel: a black `NotchShape` that grows out of the notch, with the
/// mode's content on it. Only this SwiftUI content animates; the window frame stays fixed (#11).
struct PanelView: View {
    let appModel: AppModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var panel: PanelModel { appModel.panel }
    private var isOpen: Bool { panel.mode != .closed }

    var body: some View {
        ZStack(alignment: .top) {
            backing
            content
        }
        .frame(width: PanelLayout.windowSize.width, height: PanelLayout.windowSize.height, alignment: .top)
        .onChange(of: shapeSize, initial: true) { panel.contentSize = shapeSize }
    }

    // MARK: - Shape

    /// The size of the shape's body (without the outward top corners) in the current mode.
    private var shapeSize: CGSize {
        switch panel.mode {
        case .closed:
            return panel.closedSize
        case .open:
            let rowCount = appModel.store.recent(limit: PanelLayout.recentCount).count
            return CGSize(width: PanelLayout.panelWidth, height: PanelLayout.recentPanelHeight(rowCount: rowCount))
        case .search:
            return PanelLayout.searchSize
        case .feedback:
            return CGSize(width: PanelLayout.panelWidth, height: PanelLayout.feedbackPanelHeight)
        }
    }

    private var topCornerRadius: CGFloat {
        isOpen ? PanelLayout.topCornerRadius : PanelLayout.collapsedTopCornerRadius
    }

    private var bottomCornerRadius: CGFloat {
        isOpen ? PanelLayout.bottomCornerRadius : PanelLayout.collapsedBottomCornerRadius
    }

    /// An oversized black backing masked by the shape, so a spring's overshoot never shows a gap.
    /// The shadow is drawn here; the window has none.
    private var backing: some View {
        Color.black
            .mask(alignment: .top) {
                NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
                    .frame(width: shapeSize.width + 2 * topCornerRadius, height: shapeSize.height)
                    .animation(Motion.shape(expanding: isOpen, reduceMotion: reduceMotion), value: shapeSize)
                    .animation(Motion.shape(expanding: isOpen, reduceMotion: reduceMotion), value: isOpen)
                    // The gulp when a saved card flies into the notch. None with Reduce Motion.
                    // None in search mode either, where no card flies (#10 shows a status there).
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
    private var content: some View {
        ZStack(alignment: .top) {
            switch panel.mode {
            case .closed:
                EmptyView()
            case .open, .feedback:
                // One view for both, so going from the shortcut's feedback to `.open` keeps the card
                // in place while the list comes in.
                recentContent
                    .transition(Motion.content(reduceMotion: reduceMotion))
            case .search:
                SearchView(appModel: appModel)
                    .padding(.top, PanelLayout.notchClearance)
                    .padding([.horizontal, .bottom], PanelLayout.contentPadding)
                    .frame(width: PanelLayout.searchSize.width, height: PanelLayout.searchSize.height)
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
            // The shortcut's feedback (#10) shows only the card.
            if !panel.showsOnlySaveCard {
                recentList
                showAllButton
            }
        }
        .padding(.top, PanelLayout.notchClearance)
        .padding([.horizontal, .bottom], PanelLayout.contentPadding)
        .frame(width: PanelLayout.panelWidth, height: shapeSize.height, alignment: .top)
    }

    private var recentList: some View {
        // Always read through `appModel.store`, which is replaced when the folder changes (#9).
        NoteList(
            appModel: appModel,
            notes: appModel.store.recent(limit: PanelLayout.recentCount),
            emptyText: "No notes yet"
        )
    }

    /// Expands the panel into the search view (#5).
    private var showAllButton: some View {
        Button {
            panel.mode = .search
        } label: {
            Text("Show all (\(appModel.store.notes.count))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: PanelLayout.showAllHeight)
                .contentShape(RoundedRectangle(cornerRadius: PanelLayout.rowCornerRadius))
        }
        .buttonStyle(.plain)
    }
}
