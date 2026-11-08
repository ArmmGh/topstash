import SwiftUI

/// The content of the notch panel: a black shape with rounded bottom corners hanging from the top center.
/// The real notch shape and motion come in #11.
struct PanelView: View {
    let appModel: AppModel

    private var panel: PanelModel { appModel.panel }
    private var isOpen: Bool { panel.mode == .open }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: PanelLayout.sectionSpacing) {
                SaveCard(state: panel.saveCard) { appModel.saveClipboardFromCard() }
                    .frame(height: PanelLayout.saveCardHeight)
                recentList
            }
            .padding(.top, PanelLayout.notchClearance)
            .padding([.horizontal, .bottom], PanelLayout.contentPadding)
            .frame(width: PanelLayout.panelWidth)
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
                    NoteRow(
                        note: note,
                        isCopied: panel.copiedNoteID == note.id,
                        openInEditor: { appModel.openInEditor(note) },
                        delete: { appModel.delete(note) }
                    ) {
                        appModel.copy(note)
                    }
                }
            }
        }
    }
}
