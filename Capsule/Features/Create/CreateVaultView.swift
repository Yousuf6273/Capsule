import SwiftUI
import PhotosUI

/// "Start a capsule 🌴" — name, unlock condition, cover photo (drives the theme),
/// friends via contact picker, shareable invite link.
struct CreateVaultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var onCreated: (Vault) -> Void

    @State private var name = ""
    @State private var unlockMode: UnlockMode = .date
    @State private var unlockDate = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
    @State private var coverItem: PhotosPickerItem?
    @State private var coverImage: UIImage?
    @State private var extractedTheme: TripTheme = .default
    @State private var invitedNames: [String] = []
    @State private var showContactPicker = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let previewInviteCode = MockVaultService.generateInviteCode()

    enum UnlockMode: String, CaseIterable {
        case date = "On a date"
        case everyoneReady = "When everyone's ready"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ShellBackground()
                RadialGradient(colors: [extractedTheme.primary.opacity(0.25), .clear],
                               center: .init(x: 0.5, y: 0.1), startRadius: 0, endRadius: 460)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.2), value: extractedTheme)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        coverField
                        nameField
                        unlockField
                        friendsField
                        inviteField

                        if let errorMessage {
                            Text(errorMessage)
                                .font(CapsuleFont.body(12.5, .semibold))
                                .foregroundStyle(Color.poolCoral)
                        }

                        Button(action: create) {
                            if isCreating { ProgressView().tint(.white) }
                            else { Text("Create capsule") }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(trimmedName.isEmpty || isCreating)
                        .opacity(trimmedName.isEmpty ? 0.55 : 1)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .tripTheme(extractedTheme)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GlassIconButton(systemName: "xmark") { dismiss() }
                }
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPicker { contactName in
                    if !invitedNames.contains(contactName) {
                        invitedNames.append(contactName)
                    }
                }
            }
            .onChange(of: coverItem) { _, item in
                loadCover(item)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("New vault")
                .monoLabel(size: 10, color: .capsuleDim, tracking: 1.2)
            Text("Start a capsule 🌴")
                .font(CapsuleFont.display(26, .bold))
                .foregroundStyle(Color.capsuleCream)
            Text("Name it, set the drop date, pull in the squad. Your theme is pulled from the cover photo automatically.")
                .font(CapsuleFont.body(12.5, .medium))
                .foregroundStyle(Color.capsuleDim)
                .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    private var coverField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Cover photo · sets the theme")
            PhotosPicker(selection: $coverItem, matching: .images) {
                Group {
                    if let coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .clipped()
                            .overlay(alignment: .bottomTrailing) { themeSwatches.padding(10) }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 26))
                            Text("Pick a destination shot")
                                .font(CapsuleFont.body(12.5, .semibold))
                        }
                        .foregroundStyle(Color.capsuleDim)
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                    }
                }
                .glassCard(cornerRadius: 18)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var themeSwatches: some View {
        HStack(spacing: 6) {
            Circle().fill(extractedTheme.primary).frame(width: 18, height: 18)
            Circle().fill(extractedTheme.secondary).frame(width: 18, height: 18)
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Trip name")
            TextField("", text: $name,
                      prompt: Text("Amalfi Coast, September").foregroundStyle(Color.capsuleDim2))
                .font(CapsuleFont.body(14, .medium))
                .foregroundStyle(Color.capsuleCream)
                .padding(.horizontal, 15).padding(.vertical, 14)
                .glassCard(cornerRadius: 14)
        }
    }

    private var unlockField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Opens")
            Picker("", selection: $unlockMode) {
                ForEach(UnlockMode.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)

            if unlockMode == .date {
                DatePicker("", selection: $unlockDate, in: Date.now...,
                          displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(.horizontal, 15).padding(.vertical, 8)
                    .glassCard(cornerRadius: 14)
                    .tint(extractedTheme.secondary)
            } else {
                Text("The vault opens the moment every member marks themselves ready.")
                    .font(CapsuleFont.body(12, .medium))
                    .foregroundStyle(Color.capsuleDim)
            }
        }
    }

    private var friendsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Who's coming")
            FlowChips {
                chip(initial: String(model.profile?.displayName.prefix(1) ?? "Y"), label: "You", colorIndex: 0)
                ForEach(Array(invitedNames.enumerated()), id: \.element) { i, n in
                    chip(initial: String(n.prefix(1)), label: n, colorIndex: i + 1)
                }
                Button { showContactPicker = true } label: {
                    chip(initial: "+", label: "Add friend", colorIndex: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func chip(initial: String, label: String, colorIndex: Int) -> some View {
        HStack(spacing: 6) {
            InitialAvatar(initial: initial.uppercased(), size: 22, colorIndex: colorIndex)
            Text(label)
                .font(CapsuleFont.body(12.5, .semibold))
                .foregroundStyle(Color.capsuleCream)
        }
        .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 6)
        .glassCard(cornerRadius: 24)
    }

    private var inviteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Invite link")
            HStack {
                Text("capsule.app/j/\(previewInviteCode)")
                    .font(CapsuleFont.mono(13.5, .semibold))
                    .foregroundStyle(extractedTheme.secondary)
                Spacer()
                ShareLink(item: URL(string: "https://capsule.app/j/\(previewInviteCode)")!) {
                    Text("SHARE")
                        .monoLabel(size: 10, color: .capsuleCream, tracking: 0.8)
                        .padding(.horizontal, 11).padding(.vertical, 7)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.capsuleGlassBorder, lineWidth: 1))
                }
            }
            .padding(14)
            .background(
                LinearGradient(colors: [extractedTheme.primary.opacity(0.16),
                                        extractedTheme.secondary.opacity(0.12)],
                               startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(extractedTheme.primary.opacity(0.48),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            Text("Real invite codes are minted when the capsule is created — this one is reserved for it.")
                .font(CapsuleFont.body(10.5, .medium))
                .foregroundStyle(Color.capsuleDim2)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).monoLabel(size: 10, color: extractedTheme.secondary, tracking: 1.2)
    }

    // ── Actions ──────────────────────────────────────────────────

    private func loadCover(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            coverImage = image
            withAnimation(.easeInOut(duration: 1.2)) {
                extractedTheme = ThemeExtractor.extractTheme(from: image, fallbackSeed: name)
            }
        }
    }

    private func create() {
        guard !trimmedName.isEmpty else { return }
        isCreating = true
        errorMessage = nil
        Task {
            defer { isCreating = false }
            do {
                var coverFileName: String?
                if let coverImage, let data = coverImage.jpegData(compressionQuality: 0.85) {
                    coverFileName = "cover-\(UUID().uuidString).jpg"
                    try LocalStore.save(data: data, fileName: coverFileName!)
                }
                let condition: UnlockCondition = unlockMode == .date ? .date(unlockDate) : .everyoneReady
                let vault = try await model.createVault(
                    name: trimmedName,
                    unlockCondition: condition,
                    coverImageFileName: coverFileName,
                    theme: coverImage == nil
                        ? TripTheme.fallbackPool[abs(trimmedName.hashValue) % TripTheme.fallbackPool.count]
                        : extractedTheme)
                onCreated(vault)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Simple wrapping HStack for chips.
struct FlowChips<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        // Wrapping layout: fine for a handful of chips.
        FlowLayout(spacing: 8) { content }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
