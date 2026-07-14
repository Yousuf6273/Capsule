import SwiftUI

@main
struct CapsuleApp: App {
    @State private var model: AppModel

    init() {
        #if DEBUG
        // Deterministic state for UI tests: wipe persistence before AppModel loads.
        if CommandLine.arguments.contains("--uitest-reset") {
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            for name in ["media", "memories.json", "uploadQueue.json"] {
                try? FileManager.default.removeItem(at: docs.appendingPathComponent(name))
            }
        }
        #endif
        _model = State(initialValue: AppModel())
    }

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
                    ShellBackground(showDust: false)
                    Text("CAPSULE")
                        .monoLabel(size: 12, color: Color(hex: "F4D796"), tracking: 4)
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
