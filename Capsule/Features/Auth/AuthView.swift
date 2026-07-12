import SwiftUI
import AuthenticationServices

/// Welcome + sign-in. Uses Sign in with Apple when a real backend is attached;
/// the mock path just needs a display name so the rest of the app is usable.
struct AuthView: View {
    @Environment(AppModel.self) private var model
    @State private var displayName = ""
    @State private var isSigningIn = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            ThemedMeshBackground()

            VStack(spacing: 0) {
                Spacer()

                Text("Memories, sealed")
                    .monoLabel(size: 11, color: .capsuleCream.opacity(0.85), tracking: 2.2)
                    .padding(.bottom, 12)

                Text("Capsule")
                    .font(CapsuleFont.display(44, .extraBold))
                    .foregroundStyle(Color.capsuleCream)

                Text("Lock trip photos with your friends.\nNobody peeks. Everyone opens it together.")
                    .font(CapsuleFont.body(14.5, .medium))
                    .foregroundStyle(Color.capsuleCream.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 14)

                Spacer()

                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your name")
                            .monoLabel(size: 10, color: .capsuleCream.opacity(0.9))
                        TextField("", text: $displayName, prompt: Text("e.g. Yousuf")
                            .foregroundStyle(Color.capsuleDim2))
                            .font(CapsuleFont.body(14, .medium))
                            .foregroundStyle(Color.capsuleCream)
                            .padding(.horizontal, 15).padding(.vertical, 14)
                            .glassCard(cornerRadius: 14)
                            .focused($nameFocused)
                            .submitLabel(.go)
                            .onSubmit(signIn)
                    }

                    Button(action: signIn) {
                        if isSigningIn {
                            ProgressView().tint(.white)
                        } else {
                            Text("Start sealing memories")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSigningIn)
                    .opacity(displayName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.55 : 1)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func signIn() {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !isSigningIn else { return }
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            try? await model.signIn(displayName: name)
        }
    }
}
