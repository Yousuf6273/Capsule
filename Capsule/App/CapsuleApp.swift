import SwiftUI

@main
struct CapsuleApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.isRestoringSession {
                ZStack {
                    ThemedMeshBackground()
                    Text("CAPSULE")
                        .monoLabel(size: 12, color: .capsuleCream, tracking: 4)
                }
            } else if model.isSignedIn {
                MainShell()
            } else {
                AuthView()
            }
        }
        .task { await model.restore() }
    }
}
