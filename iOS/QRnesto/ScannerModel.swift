import AVFoundation
import QRCore
import SwiftUI
import UIKit

@MainActor
final class ScannerModel: ObservableObject {
    @Published var image: UIImage?
    @Published var results: [ParsedPayload] = []
    @Published var status = "Scan with the camera, pick a photo, or paste an image."

    @Published var cameraOn = false
    let camera = CameraScanner()
    private var timeoutTask: Task<Void, Never>?
    private let haptics = UINotificationFeedbackGenerator()

    func toggleCamera() {
        if cameraOn { stopCamera(); return }
        image = nil
        results = []
        status = "Starting camera…"
        camera.onCode = { [weak self] raw in self?.cameraDetected(raw) }
        Task {
            do {
                try await camera.start()
                cameraOn = true
                status = "Point the camera at a QR code or barcode."
                scheduleTimeout()
            } catch CameraScanner.StartError.denied {
                status = "Camera access denied. Enable it in Settings › Privacy & Security › Camera."
            } catch CameraScanner.StartError.noCamera {
                status = "No camera available on this device."
            } catch {
                status = "Could not start the camera: \(error.localizedDescription)"
            }
        }
    }

    func stopCamera() {
        guard cameraOn else { return }
        timeoutTask?.cancel()
        camera.stop()
        cameraOn = false
        status = results.isEmpty ? "Camera stopped." : "Camera stopped. \(results.count) code(s) scanned."
    }

    private func scheduleTimeout() {
        timeoutTask?.cancel()
        let defaults = UserDefaults.standard
        let seconds = defaults.object(forKey: Prefs.cameraTimeoutKey) as? Int ?? Prefs.defaultCameraTimeout
        guard seconds > 0 else { return }
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            guard !Task.isCancelled, let self, self.cameraOn else { return }
            self.stopCamera()
            self.status = "Camera stopped automatically after \(seconds) s."
        }
    }

    func remove(_ payload: ParsedPayload) {
        results.removeAll { $0.id == payload.id }
    }

    private func cameraDetected(_ raw: String) {
        guard !results.contains(where: { $0.raw == raw }) else { return }
        results.insert(PayloadParser.parse(raw), at: 0)
        haptics.notificationOccurred(.success)
        status = "Scanned \(results.count) code\(results.count == 1 ? "" : "s")."
    }

    func pasteImage() {
        guard let img = UIPasteboard.general.image else { status = "No image on the clipboard."; return }
        load(img)
    }

    func load(data: Data) {
        guard let img = UIImage(data: data) else { status = "Could not read this photo as an image."; return }
        load(img)
    }

    private func load(_ img: UIImage) {
        guard let cg = img.normalizedCGImage else { status = "Could not read this image."; return }
        scan(cg, preview: img)
    }

    private func scan(_ cg: CGImage, preview: UIImage) {
        stopCamera()
        image = preview
        status = "Scanning…"
        Task {
            let payloads = await Task.detached { QRDecoder.decode(cg) }.value
            results = payloads.map(PayloadParser.parse)
            status = payloads.isEmpty ? "No QR code or barcode found in this image."
                : "Found \(payloads.count) code\(payloads.count == 1 ? "" : "s")."
        }
    }
}

private extension UIImage {
    /// Photos are often stored rotated with an orientation flag; redraw upright so Vision sees what the user sees.
    var normalizedCGImage: CGImage? {
        if imageOrientation == .up, let cg = cgImage { return cg }
        return UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = scale; return f }())
            .image { _ in draw(at: .zero) }.cgImage
    }
}
