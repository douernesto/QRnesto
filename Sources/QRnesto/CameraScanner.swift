import AVFoundation
import QRCore
import SwiftUI

/// Runs an AVCaptureSession and reports each QR payload found in the live frames.
final class CameraScanner: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    var onCode: ((String) -> Void)?
    private let queue = DispatchQueue(label: "qr.camera")
    private var configured = false
    private var lastScan = Date.distantPast

    enum StartError: Error { case denied, noCamera, setupFailed }

    func start() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { throw StartError.denied }
        default: throw StartError.denied
        }
        if !configured { try configure() }
        queue.async { [session] in if !session.isRunning { session.startRunning() } }
    }

    func stop() {
        queue.async { [session] in if session.isRunning { session.stopRunning() } }
    }

    private func configure() throws {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video, position: .unspecified)
        guard let device = AVCaptureDevice.default(for: .video) ?? discovery.devices.first
        else { throw StartError.noCamera }

        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canAddInput(input), session.canAddOutput(output) else { throw StartError.setupFailed }
        session.addInput(input)
        session.addOutput(output)
        configured = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // ~6 scans per second is plenty and keeps CPU low.
        guard Date().timeIntervalSince(lastScan) > 0.15,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastScan = Date()
        for payload in QRDecoder.decode(buffer) {
            DispatchQueue.main.async { [weak self] in self?.onCode?(payload) }
        }
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = layer
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
