import SwiftUI

enum Prefs {
    static let cameraTimeoutKey = "cameraTimeoutSeconds"
    static let defaultCameraTimeout = 120
}

struct SettingsView: View {
    @AppStorage(Prefs.cameraTimeoutKey) private var timeout = Prefs.defaultCameraTimeout

    var body: some View {
        Form {
            Stepper(value: $timeout, in: 0...3600, step: 30) {
                Text("Stop camera automatically after: \(label)")
            }
            Text("Saves battery and turns the camera off if you forget it. Set to 0 to keep it on until you stop it.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 420)
    }

    private var label: String {
        guard timeout > 0 else { return "Never" }
        let (m, s) = (timeout / 60, timeout % 60)
        return [m > 0 ? "\(m) min" : nil, s > 0 ? "\(s) s" : nil].compactMap { $0 }.joined(separator: " ")
    }
}
