import SwiftUI

/// The entrance. Dark, warm, dust drifting — the first hint that this is
/// a keepsake, not an app. Text arrives in stages; the CTA is champagne.
struct AuthView: View {
    @Environment(AppModel.self) private var model
    @State private var displayName = ""
    @State private var isSigningIn = false
    @State private var stage = 0
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            ShellBackground(showDust: false)
            GoldenDust(count: 30, baseOpacity: 0.7)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                Text("MEMORIES, SEALED")
                    .monoLabel(size: 11, color: Color(hex: "F4D796").opacity(0.9), tracking: 3.2)
                    .opacity(stage >= 1 ? 1 : 0)
                    .offset(y: stage >= 1 ? 0 : 14)
                    .padding(.bottom, 14)

                Text("Capsule")
                    .font(CapsuleFont.display(46, .extraBold))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.capsuleCream, Color(hex: "F4D796")],
                                       startPoint: .top, endPoint: .bottom))
                    .opacity(stage >= 2 ? 1 : 0)
                    .scaleEffect(stage >= 2 ? 1 : 0.94)

                Text("Lock the trip away with your friends.\nNobody peeks. Everyone opens it together.")
                    .font(CapsuleFont.body(14.5, .medium))
                    .foregroundStyle(Color.capsuleCream.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.top, 16)
                    .opacity(stage >= 3 ? 1 : 0)
                    .offset(y: stage >= 3 ? 0 : 10)

                Spacer()

                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR NAME")
                            .monoLabel(size: 10, color: Color(hex: "F4D796").opacity(0.8), tracking: 1.8)
                        TextField("", text: $displayName, prompt: Text("e.g. Yousuf")
                            .foregroundStyle(Color.capsuleDim2))
                            .font(CapsuleFont.body(15, .medium))
                            .foregroundStyle(Color.capsuleCream)
                            .padding(.horizontal, 16).padding(.vertical, 15)
                            .glassCard(cornerRadius: 16)
                            .focused($nameFocused)
                            .accessibilityIdentifier("nameField")
                            .submitLabel(.go)
                            .onSubmit(signIn)
                    }

                    Button(action: signIn) {
                        if isSigningIn {
                            ProgressView().tint(Color(hex: "17141C"))
                        } else {
                            Text("Begin")
                        }
                    }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSigningIn)
                    .opacity(displayName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 44)
                .opacity(stage >= 4 ? 1 : 0)
                .offset(y: stage >= 4 ? 0 : 18)
            }
        }
        .task {
            for s in 1...4 {
                withAnimation(.spring(duration: 0.8, bounce: 0.2)) { stage = s }
                try? await Task.sleep(for: .milliseconds(s == 1 ? 350 : 260))
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
