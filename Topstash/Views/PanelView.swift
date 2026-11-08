import SwiftUI

/// The content of the notch panel: a black shape with rounded bottom corners hanging from the top center.
/// The real notch shape and motion come in #11.
struct PanelView: View {
    let appModel: AppModel

    private var panel: PanelModel { appModel.panel }
    private var isOpen: Bool { panel.mode != .closed }
    private var isSearching: Bool { panel.mode == .search }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if isSearching {
                    SearchView(appModel: appModel)
                } else {
                    VStack(spacing: PanelLayout.sectionSpacing) {
                        SaveCard { _ = appModel.saveClipboard() }
                            .frame(height: PanelLayout.saveCardHeight)
                        recentList
                        showAllButton
                    }
                }
            }
            .padding(.top, PanelLayout.notchClearance)
            .padding([.horizontal, .bottom], PanelLayout.contentPadding)
            .frame(
                width: isSearching ? PanelLayout.searchSize.width : PanelLayout.panelWidth,
                height: isSearching ? PanelLayout.searchSize.height : nil
            )
            .background(.black, in: UnevenRoundedRectangle(
                bottomLeadingRadius: PanelLayout.bottomCornerRadius,
                bottomTrailingRadius: PanelLayout.bottomCornerRadius
            ))
            .onGeometryChange(for: CGSize.self, of: \.size) { panel.contentSize = $0 }
            .opacity(isOpen ? 1 : 0)
            .allowsHitTesting(isOpen)
            .animation(.easeInOut(duration: PanelLayout.fadeDuration), value: isOpen)
            Spacer(minLength: 0)
        }
        .frame(width: PanelLayout.windowSize.width, height: PanelLayout.windowSize.height)
    }

    @ViewBuilder
    private var recentList: some View {
        // Always read through `appModel.store`, which is replaced when the folder changes (#9).
        let notes = appModel.store.recent(limit: PanelLayout.recentCount)
        if notes.isEmpty {
            Text("No notes yet")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, minHeight: PanelLayout.rowHeight)
        } else {
            VStack(spacing: PanelLayout.rowSpacing) {
                ForEach(notes) { note in
                    NoteRow(note: note, isCopied: panel.copiedNoteID == note.id) {
                        appModel.copy(note)
                    }
                }
            }
        }
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
