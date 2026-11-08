import SwiftUI

/// The card that saves the clipboard text as a note. Card states come in #3.
struct SaveCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                Text("Save clipboard")
                    .font(.system(size: 14, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: PanelLayout.cardCornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: PanelLayout.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }
}
