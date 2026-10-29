import SwiftUI

@main
struct QRnestoApp: App {
    @StateObject private var model = ScannerModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { model.stopCamera() }
        }
    }
}
