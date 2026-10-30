import SwiftUI

enum Prefs {
    static let cameraTimeoutKey = "cameraTimeoutSeconds"
    static let defaultCameraTimeout = 120
}

struct SettingsView: View {
    @AppStorage(Prefs.cameraTimeoutKey) private var timeout = Prefs.defaultCameraTimeout
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $timeout, in: 0...3600, step: 30) {
                        Text("Stop camera after: \(label)")
                    }
                } footer: {
                    Text("Saves battery and turns the camera off if you forget it. Set to 0 to keep it on until you stop it.")
                }
                Section("About") {
                    Text("Scan QR codes and barcodes (EAN, UPC, Code 128, Data Matrix, PDF417, Aztec and more) from the camera, a photo or the clipboard, and see what they contain as labelled fields.\n\nEverything is decoded on your device. Links are never opened automatically.")
                        .font(.footnote)
                    Link("github.com/douernesto/QRnesto", destination: URL(string: "https://github.com/douernesto/QRnesto")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private var label: String {
        guard timeout > 0 else { return "Never" }
        let (m, s) = (timeout / 60, timeout % 60)
        return [m > 0 ? "\(m) min" : nil, s > 0 ? "\(s) s" : nil].compactMap { $0 }.joined(separator: " ")
    }
}
