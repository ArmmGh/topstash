import SwiftUI

/// The content of the notch panel: a black shape with rounded bottom corners hanging from the top center.
/// The real notch shape and motion come in #11.
struct PanelView: View {
    let appModel: AppModel

    private var panel: PanelModel { appModel.panel }
    private var isOpen: Bool { panel.mode == .open }

    var body: some View {
        VStack(spacing: 0) {
            SaveCard { _ = appModel.saveClipboard() }
                .padding(.top, PanelLayout.notchClearance)
                .padding([.horizontal, .bottom], PanelLayout.contentPadding)
                .frame(width: PanelLayout.panelSize.width, height: PanelLayout.panelSize.height)
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
}
