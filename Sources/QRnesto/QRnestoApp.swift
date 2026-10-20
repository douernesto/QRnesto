import SwiftUI

@main
struct QRnestoApp: App {
    @StateObject private var model = ScannerModel()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("QRnesto") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 640, minHeight: 460)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Image…") { model.openFile() }.keyboardShortcut("o")
                Button("Paste Image") { model.pasteImage() }.keyboardShortcut("v", modifiers: [.command, .shift])
                Button("Capture Screen Region") { model.captureScreen() }.keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Toggle Camera") { model.toggleCamera() }.keyboardShortcut("k")
            }
        }
    }
}
