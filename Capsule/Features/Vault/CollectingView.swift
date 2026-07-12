import SwiftUI
import PhotosUI

/// Collecting screen: full-bleed cover header, "memory sealed" toast on upload,
/// locked/obscured grid of your own drops, member strip.
/// (Local-only for now — the offline queue + real upload pipeline is milestone 2.)
struct CollectingView: View {
    @Environment(\.tripTheme) private var theme
    let vault: Vault

    @State private var sealedCount: Int
    @State private var lockedThumbs: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var toastPulse = false

    init(vault: Vault) {
        self.vault = vault
        _sealedCount = State(initialValue: vault.memoryCount)
    }

    var body: some View {
        ZStack {
            Color.capsuleCharcoal2.ignoresSafeArea()
            ThemedMeshBackground().opacity(0.35)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    VStack(alignment: .leading, spacing: 18) {
                        toast
                        memberStrip

                        HStack {
                            Text("Your drops")
                                .font(CapsuleFont.display(15, .bold))
                                .foregroundStyle(Color.capsuleCream)
                            Spacer()
                            Text("\(lockedThumbs.count)")
                                .font(CapsuleFont.mono(11, .medium))
                                .foregroundStyle(Color.capsuleDim2)
                        }

                        lockedGrid

                        NavigationLink(value: "waiting-\(vault.id)") {
                            Text("Done adding for now")
                        }
                        .buttonStyle(GlassButtonStyle())
                        .padding(.top, 8)
                    }
                    .padding(18)
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationDestination(for: String.self) { key in
            if key == "waiting-\(vault.id)" {
                WaitingView(vault: vault).tripTheme(vault.theme)
            }
        }
        .onChange(of: pickerItems) { _, items in
            ingest(items)
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            CoverArt(vault: vault, dimmed: true)
                .frame(height: 280)
                .clipped()
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "0A0F1C").opacity(0.1), location: 0),
                    .init(color: Color(hex: "0A0F1C").opacity(0.35), location: 0.55),
                    .init(color: Color.capsuleCharcoal2, location: 1),
                ],
                startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 5) {
                Text(vault.subtitle ?? vault.displayName)
                    .font(CapsuleFont.display(26, .extraBold))
                    .foregroundStyle(Color.capsuleCream)
                Text("Every drop is sealed — no peeking, not even you.")
                    .font(CapsuleFont.body(12, .medium))
                    .foregroundStyle(Color.capsuleDim)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(height: 280)
    }

    private var toast: some View {
        HStack(spacing: 10) {
            Text("🔒").font(.system(size: 18))
                .scaleEffect(toastPulse ? 1.25 : 1)
            (Text("Another memory sealed. ")
                .foregroundStyle(Color.capsuleCream)
             + Text("\(sealedCount) total")
                .foregroundStyle(theme.secondary))
                .font(CapsuleFont.body(12.5, .semibold))
        }
        .padding(.horizontal, 15).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [theme.primary.opacity(0.18), theme.secondary.opacity(0.12)],
                           startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.primary.opacity(0.38), lineWidth: 1))
        .scaleEffect(toastPulse ? 1.02 : 1)
    }

    private var memberStrip: some View {
        HStack(spacing: -9) {
            ForEach(Array(vault.members.enumerated()), id: \.element.id) { i, member in
                InitialAvatar(initial: member.initial, size: 32, colorIndex: i)
                    .overlay(Circle().strokeBorder(Color.capsuleCharcoal2, lineWidth: 2.5))
            }
        }
    }

    private var lockedGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Array(lockedThumbs.enumerated()), id: \.offset) { _, thumb in
                ZStack {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                    Color(hex: "0A0F1C").opacity(0.35)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.capsuleCream)
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.capsuleGlassBorder, lineWidth: 1.5))
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }

            PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos])) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.capsuleGlassBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme.secondary)
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    /// Generates the locked derivative immediately — heavily blurred + darkened,
    /// matching the mockup's `.film-cell` treatment. Originals never render here.
    private func ingest(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        pickerItems = []
        Task {
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let locked = Self.lockedThumbnail(from: image) else { continue }
                withAnimation(.spring(duration: 0.45)) {
                    lockedThumbs.append(locked)
                    sealedCount += 1
                }
                withAnimation(.spring(duration: 0.3)) { toastPulse = true }
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.spring(duration: 0.3)) { toastPulse = false }
            }
        }
    }

    static func lockedThumbnail(from image: UIImage) -> UIImage? {
        let side: CGFloat = 120
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // Downscale tiny, then draw scaled up — cheap, irreversible obscuring.
        let tiny = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12), format: format).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
            tiny.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
            UIColor.black.withAlphaComponent(0.45).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
    }
}
