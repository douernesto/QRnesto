import QRCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: ScannerModel
    @State private var targeted = false

    var body: some View {
        HSplitView {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(targeted ? Color.accentColor : .secondary.opacity(0.4),
                                      style: StrokeStyle(lineWidth: 2, dash: [6]))
                    if model.cameraOn {
                        CameraPreview(session: model.camera.session)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let image = model.image {
                        Image(nsImage: image).resizable().scaledToFit().padding(8)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode.viewfinder").font(.system(size: 48))
                            Text("Drop an image here").foregroundStyle(.secondary)
                        }
                    }
                }
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first else { return false }
                    model.load(url: url); return true
                } isTargeted: { targeted = $0 }

                VStack(spacing: 8) {
                    HStack {
                        Button("Open…") { model.openFile() }
                        Button("Paste") { model.pasteImage() }
                        Button("Capture Screen") { model.captureScreen() }
                    }
                    Button { model.toggleCamera() } label: {
                        Label(model.cameraOn ? "Stop Camera" : "Use Camera",
                              systemImage: model.cameraOn ? "video.slash" : "video")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Text(model.status).font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .frame(minWidth: 340)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(model.results) { ResultCard(payload: $0) }
                    if model.results.isEmpty {
                        Text("Decoded content will appear here.").foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 320)
        }
    }
}

struct ResultCard: View {
    let payload: ParsedPayload
    @State private var showRaw = false
    @State private var revealed = Set<UUID>()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(payload.kind, systemImage: payload.symbol).font(.headline)

            ForEach(payload.fields) { field in
                HStack(alignment: .top) {
                    Text(field.label).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
                    let hidden = field.isSecret && !revealed.contains(field.id)
                    Text(hidden ? String(repeating: "•", count: 8) : field.value).textSelection(.enabled)
                    Spacer()
                    if field.isSecret {
                        Button(hidden ? "Show" : "Hide") {
                            if hidden { revealed.insert(field.id) } else { revealed.remove(field.id) }
                        }.buttonStyle(.link)
                    }
                    Button { copy(field.value) } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless).help("Copy")
                }
            }

            HStack {
                if let title = payload.actionTitle, let url = payload.actionURL {
                    Button(title) { NSWorkspace.shared.open(url) }
                }
                Button("Copy raw") { copy(payload.raw) }
                Toggle("Show raw", isOn: $showRaw).toggleStyle(.button)
            }
            if showRaw {
                Text(payload.raw).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}
