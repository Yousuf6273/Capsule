import SwiftUI

/// Screen 5 — the finale. One quiet line, then a slow fade into the
/// permanent gallery (the router swaps to AlbumView when we mark done).
struct FinaleView: View {
    @Environment(\.tripTheme) private var theme
    var onFadeOut: () -> Void

    @State private var lineVisible = false
    @State private var fading = false

    var body: some View {
        ZStack {
            Color(hex: "0D0B10").ignoresSafeArea()

            RadialGradient(colors: [Color(hex: "D9B26A").opacity(0.12),
                                    theme.primary.opacity(0.07), .clear],
                           center: .center, startRadius: 0, endRadius: 400)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("✨")
                    .font(.system(size: 34))
                Text("Until the next adventure.")
                    .font(CapsuleFont.display(24, .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.capsuleCream, Color(hex: "F4D796")],
                                       startPoint: .top, endPoint: .bottom))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .opacity(lineVisible && !fading ? 1 : 0)
            .scaleEffect(lineVisible ? 1 : 0.96)
        }
        .task {
            withAnimation(.easeOut(duration: 1.2)) { lineVisible = true }
            try? await Task.sleep(for: .milliseconds(2600))
            withAnimation(.easeIn(duration: 0.9)) { fading = true }
            try? await Task.sleep(for: .milliseconds(950))
            onFadeOut()
        }
    }
}
