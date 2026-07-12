import SwiftUI

/// The signature unlock moment. Timing mirrors the mockup exactly:
/// text at 0.3s → light bloom at 1.4s → doors slide at 2.0s (1.4s, cubic-bezier(.7,0,.2,1))
/// → auto-advance at 3.5s.
struct UnlockDoorsView: View {
    @Environment(\.tripTheme) private var theme
    let vault: Vault
    let stats: RecapStats
    var onFinished: () -> Void

    @State private var showText = false
    @State private var showLight = false
    @State private var doorsOpen = false

    private let doorCurve = Animation.timingCurve(0.7, 0, 0.2, 1, duration: 1.4)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                // Warm light flooding through the gap
                theme.doorLight
                    .opacity(showLight ? 1 : 0)
                    .animation(.easeInOut(duration: 1.0), value: showLight)
                    .scaleEffect(doorsOpen ? 1.25 : 1)
                    .animation(doorCurve, value: doorsOpen)

                // Trip name + stats between the panels
                VStack(spacing: 8) {
                    Text("\(vault.name) is opening")
                        .font(CapsuleFont.display(22, .extraBold))
                        .foregroundStyle(.white)
                        .shadow(color: theme.primary.opacity(0.82), radius: 15)
                    Text("\(stats.totalMemories) memories · \(stats.friendCount) friends · sealed \(stats.sealedDays) days")
                        .font(CapsuleFont.body(12, .medium))
                        .foregroundStyle(Color(hex: "FFF6E9").opacity(0.75))
                }
                .opacity(showText ? 1 : 0)
                .animation(.easeInOut(duration: 0.6), value: showText)

                // Door panels
                doorPanel(leading: true)
                    .frame(width: geo.size.width / 2)
                    .offset(x: doorsOpen ? -geo.size.width / 2 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                doorPanel(leading: false)
                    .frame(width: geo.size.width / 2)
                    .offset(x: doorsOpen ? geo.size.width / 2 : 0)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .animation(doorCurve, value: doorsOpen)
        }
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .heavy), trigger: doorsOpen)
        .task { await runSequence() }
    }

    private func doorPanel(leading: Bool) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "171018"), Color(hex: "05070C")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.white.opacity(0.85))
                .offset(x: leading ? 22 : -22) // half a lock peeks past each edge
        }
        .overlay(alignment: leading ? .trailing : .leading) {
            Rectangle()
                .fill(theme.primary.opacity(0.3))
                .frame(width: 1)
        }
        .ignoresSafeArea()
    }

    private func runSequence() async {
        try? await Task.sleep(for: .milliseconds(300))
        showText = true
        try? await Task.sleep(for: .milliseconds(1100))
        showLight = true
        try? await Task.sleep(for: .milliseconds(600))
        doorsOpen = true
        try? await Task.sleep(for: .milliseconds(1500))
        onFinished()
    }
}
