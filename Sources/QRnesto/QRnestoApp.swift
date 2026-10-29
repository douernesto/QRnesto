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
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About QRnesto") { showAbout() }
            }
            CommandGroup(after: .newItem) {
                Button("Open Image…") { model.openFile() }.keyboardShortcut("o")
                Button("Paste Image") { model.pasteImage() }.keyboardShortcut("v", modifiers: [.command, .shift])
                Button("Capture Screen Region") { model.captureScreen() }.keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Toggle Camera") { model.toggleCamera() }.keyboardShortcut("k")
            }
        }
    }

    private func showAbout() {
        let credits = NSMutableAttributedString(
            string: "Scan QR codes and barcodes (EAN, UPC, Code 128, Data Matrix, PDF417, Aztec and more) from the camera, an image, the clipboard or your screen, and see what they contain as labelled fields.\n\nEverything is decoded on your Mac. Links are never opened automatically.\n\n",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor])
        credits.append(NSAttributedString(
            string: "github.com/douernesto/QRnesto",
            attributes: [.font: NSFont.systemFont(ofSize: 11),
                         .link: URL(string: "https://github.com/douernesto/QRnesto")!]))
        credits.addAttribute(.paragraphStyle, value: {
            let style = NSMutableParagraphStyle(); style.alignment = .center; return style
        }(), range: NSRange(location: 0, length: credits.length))
        NSApplication.shared.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
