import AppKit
import AVFoundation
import QRCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ScannerModel: ObservableObject {
    @Published var image: NSImage?
    @Published var results: [ParsedPayload] = []
    @Published var status = "Drop an image, paste one, or capture a region of your screen."

    @Published var cameraOn = false
    @Published var mirrored = true
    let camera = CameraScanner()
    private var timeoutTask: Task<Void, Never>?

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
                status = "Point a QR code or barcode at the camera."
                scheduleTimeout()
            } catch CameraScanner.StartError.denied {
                status = "Camera access denied. Enable it in System Settings › Privacy & Security › Camera."
            } catch CameraScanner.StartError.noCamera {
                status = "No camera found on this Mac."
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
        NSSound.beep()
        status = "Scanned \(results.count) code\(results.count == 1 ? "" : "s")."
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { load(url: url) }
    }

    func pasteImage() {
        guard let img = NSImage(pasteboard: .general), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { status = "No image on the clipboard."; return }
        scan(cg, preview: img)
    }

    func captureScreen() {
        let path = NSTemporaryDirectory() + "qr-capture-\(UUID().uuidString).png"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-x", path]
        task.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard FileManager.default.fileExists(atPath: path) else {
                    self?.status = "Capture cancelled (or Screen Recording permission is not granted)."
                    return
                }
                self?.load(url: URL(fileURLWithPath: path))
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        try? task.run()
    }

    func load(url: URL) {
        guard let img = NSImage(contentsOf: url),
              let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { status = "Could not read “\(url.lastPathComponent)” as an image."; return }
        scan(cg, preview: img)
    }

    private func scan(_ cg: CGImage, preview: NSImage) {
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
