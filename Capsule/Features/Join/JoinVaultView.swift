import SwiftUI

/// Join a vault with an invite code (or via capsule.app/j/CODE deep link).
struct JoinVaultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var prefilledCode: String = ""
    var onJoined: (Vault) -> Void

    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedMeshBackground()

                VStack(spacing: 18) {
                    Text("🎟")
                        .font(.system(size: 40))
                        .padding(.top, 30)
                    Text("Join a capsule")
                        .font(CapsuleFont.display(24, .bold))
                        .foregroundStyle(Color.capsuleCream)
                    Text("Paste the invite code your friend sent you.")
                        .font(CapsuleFont.body(13, .medium))
                        .foregroundStyle(Color.capsuleDim)

                    TextField("", text: $code, prompt: Text("8QK2VN").foregroundStyle(Color.capsuleDim2))
                        .font(CapsuleFont.mono(20, .bold))
                        .foregroundStyle(Color.capsuleCream)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.vertical, 16)
                        .glassCard(cornerRadius: 16)
                        .padding(.horizontal, 40)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(CapsuleFont.body(12.5, .semibold))
                            .foregroundStyle(Color.poolCoral)
                    }

                    Button(action: join) {
                        if isJoining { ProgressView().tint(.white) }
                        else { Text("Join the vault") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(code.trimmingCharacters(in: .whitespaces).count < 4 || isJoining)
                    .opacity(code.trimmingCharacters(in: .whitespaces).count < 4 ? 0.55 : 1)
                    .padding(.horizontal, 40)

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GlassIconButton(systemName: "xmark") { dismiss() }
                }
            }
            .onAppear { code = prefilledCode }
        }
        .preferredColorScheme(.dark)
    }

    private func join() {
        isJoining = true
        errorMessage = nil
        Task {
            defer { isJoining = false }
            do {
                let vault = try await model.joinVault(inviteCode: code)
                onJoined(vault)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
