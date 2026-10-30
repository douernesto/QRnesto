import PhotosUI
import QRCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: ScannerModel
    @State private var photo: PhotosPickerItem?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    preview
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Button { model.toggleCamera() } label: {
                            Label(model.cameraOn ? "Stop" : "Camera",
                                  systemImage: model.cameraOn ? "video.slash" : "camera.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        PhotosPicker(selection: $photo, matching: .images) {
                            Label("Photo", systemImage: "photo").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        Button { model.pasteImage() } label: {
                            Label("Paste", systemImage: "doc.on.clipboard").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.large)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                    Text(model.status).font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    ForEach(model.results) { payload in
                        ResultCard(payload: payload) { model.remove(payload) }
                    }
                    if model.results.isEmpty {
                        Text("Decoded content will appear here.").foregroundStyle(.secondary).padding(.top)
                    }
                }
                .padding()
            }
            .navigationTitle("QRnesto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onChange(of: photo) { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) { model.load(data: data) }
                    photo = nil
                }
            }
        }
    }

    @ViewBuilder private var preview: some View {
        if model.cameraOn {
            CameraPreview(session: model.camera.session)
        } else if let image = model.image {
            Image(uiImage: image).resizable().scaledToFit().padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "qrcode.viewfinder").font(.system(size: 56))
                Text("Scan a code to get started").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemBackground))
        }
    }
}

struct ResultCard: View {
    let payload: ParsedPayload
    let onRemove: () -> Void
    @State private var showRaw = false
    @State private var revealed = Set<UUID>()
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(payload.kind, systemImage: payload.symbol).font(.headline)
                Spacer()
                Button(action: onRemove) { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).accessibilityLabel("Remove")
            }

            ForEach(payload.fields) { field in
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.label).font(.caption).foregroundStyle(.secondary)
                    HStack(alignment: .top) {
                        let hidden = field.isSecret && !revealed.contains(field.id)
                        Text(hidden ? String(repeating: "•", count: 8) : field.value).textSelection(.enabled)
                        Spacer()
                        if field.isSecret {
                            Button(hidden ? "Show" : "Hide") {
                                if hidden { revealed.insert(field.id) } else { revealed.remove(field.id) }
                            }.buttonStyle(.borderless)
                        }
                        Button { copy(field.value) } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.borderless).accessibilityLabel("Copy")
                    }
                }
            }

            HStack {
                if let title = payload.actionTitle, let url = payload.actionURL {
                    Button(title) { openURL(url) }.buttonStyle(.borderedProminent)
                }
                Button("Copy raw") { copy(payload.raw) }.buttonStyle(.bordered)
                Toggle("Show raw", isOn: $showRaw).toggleStyle(.button)
            }
            .controlSize(.small)
            if showRaw {
                Text(payload.raw).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func copy(_ s: String) {
        UIPasteboard.general.string = s
    }
}
