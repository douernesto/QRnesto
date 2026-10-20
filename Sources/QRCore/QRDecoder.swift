import CoreImage
import Foundation
import ImageIO
import Vision

public enum QRDecoder {
    /// Detects every QR code in the image and returns the raw payload of each.
    /// Retries on a colour-inverted copy because Vision does not read light-on-dark codes.
    public static func decode(_ image: CGImage) -> [String] {
        let found = detect(in: image)
        if !found.isEmpty { return found }
        let ci = CIImage(cgImage: image).applyingFilter("CIColorInvert")
        if let inverted = CIContext().createCGImage(ci, from: ci.extent) {
            return detect(in: inverted)
        }
        return []
    }

    public static func decode(fileAt url: URL) -> (image: CGImage, payloads: [String])? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return (image, decode(image))
    }

    /// Decodes a live camera frame.
    public static func decode(_ buffer: CVPixelBuffer) -> [String] {
        detect(handler: VNImageRequestHandler(cvPixelBuffer: buffer))
    }

    private static func detect(in image: CGImage) -> [String] {
        detect(handler: VNImageRequestHandler(cgImage: image))
    }

    private static func detect(handler: VNImageRequestHandler) -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr, .microQR]
        try? handler.perform([request])

        var seen = Set<String>()
        return (request.results ?? []).compactMap { obs in
            let text: String?
            if let s = obs.payloadStringValue {
                text = s
            } else if let d = obs.barcodeDescriptor as? CIQRCodeDescriptor {
                // Binary payload that is not valid text: show it as hex.
                text = d.errorCorrectedPayload.map { String(format: "%02x", $0) }.joined()
            } else {
                text = nil
            }
            guard let t = text, seen.insert(t).inserted else { return nil }
            return t
        }
    }
}
