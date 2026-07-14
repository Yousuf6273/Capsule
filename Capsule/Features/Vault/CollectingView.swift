import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Collecting screen: full-bleed cover header, "memory sealed" toast on upload,
/// locked/obscured grid of your own drops, member strip. Uploads go through the
/// offline-tolerant UploadQueue — sealing is instant and local, sync follows.
struct CollectingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tripTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let vault: Vault

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var toastPulse = false

    private var myDrops: [Memory] {
        guard let uid = model.profile?.id else { return [] }
        return model.memoryStore.myDrops(vaultId: vault.id, userId: uid)
    }

    private var pendingCount: Int {
        model.uploadQueue.pendingCount(vaultId: vault.id)
    }

    private var sealedTotal: Int {
        max(vault.memoryCount, myDrops.count) + pendingCount
    }

    var body: some View {
        ZStack {
            Color(hex: "121016").ignoresSafeArea()
            RadialGradient(colors: [theme.primary.opacity(0.22), .clear],
                           center: .init(x: 0.8, y: 0.75), startRadius: 0, endRadius: 480)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    VStack(alignment: .leading, spacing: 18) {
                        toast
                        if !model.uploadQueue.isOnline && pendingCount > 0 {
                            offlineBanner
                        }
                        memberStrip

                        HStack {
                            Text("Your drops")
                                .font(CapsuleFont.display(15, .bold))
                                .foregroundStyle(Color.capsuleCream)
                            Spacer()
                            Text("\(myDrops.count + pendingCount)")
                                .font(CapsuleFont.mono(11, .medium))
                                .foregroundStyle(Color.capsuleDim2)
                        }

                        lockedGrid

                        Button("Done for now") { dismiss() }
                            .buttonStyle(GlassButtonStyle())
                            .padding(.top, 8)
                    }
                    .padding(18)
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(edges: .top)
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
             + Text("\(sealedTotal) total")
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

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .semibold))
            Text("\(pendingCount) sealed offline — will sync when you're back in signal")
                .font(CapsuleFont.body(11.5, .semibold))
        }
        .foregroundStyle(Color.poolGold)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 14)
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
            ForEach(myDrops) { memory in
                lockedCell(model.memoryStore.lockedThumb(for: memory), pending: false)
            }
            ForEach(model.uploadQueue.pending.filter { $0.vaultId == vault.id }) { item in
                lockedCell(LocalStore.image(named: item.lockedThumbFileName), pending: true)
            }

            PhotosPicker(selection: $pickerItems, maxSelectionCount: 10,
                         matching: .any(of: [.videos, .images])) {
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

    private func lockedCell(_ thumb: UIImage?, pending: Bool) -> some View {
        ZStack {
            if let thumb {
                Image(uiImage: thumb).resizable().scaledToFill()
            } else {
                Color.capsuleCharcoal3
            }
            Color(hex: "0A0F1C").opacity(0.35)
            Image(systemName: pending ? "arrow.triangle.2.circlepath" : "lock.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(pending ? Color.poolGold : Color.capsuleCream)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.capsuleGlassBorder, lineWidth: 1.5))
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    private func ingest(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        pickerItems = []
        Task {
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let videoType = item.supportedContentTypes.first { $0.conforms(to: .movie) }
                let ext = videoType?.preferredFilenameExtension
                withAnimation(.spring(duration: 0.45)) {
                    model.uploadQueue.enqueue(data: data, vaultId: vault.id, capturedAt: .now,
                                              mediaType: videoType != nil ? .video : .photo,
                                              fileExtension: ext)
                }
                withAnimation(.spring(duration: 0.3)) { toastPulse = true }
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.spring(duration: 0.3)) { toastPulse = false }
            }
        }
    }

    /// Locked derivative: heavily pixelated + darkened, matching `.film-cell`.
    static func lockedThumbnail(from image: UIImage) -> UIImage? {
        let side: CGFloat = 120
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
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
