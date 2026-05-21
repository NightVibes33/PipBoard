import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: PlaybackModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    playerArea
                    inputArea
                    resolverArea
                    streamsArea
                    browserArea
                    statusArea
                }
                .padding()
            }
            .navigationTitle("PipBoard")
        }
    }

    @ViewBuilder
    private var playerArea: some View {
        if let url = model.activeVideoURL {
            PiPPlayerView(url: url)
                .frame(minHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            ContentUnavailableView("No Stream Loaded", systemImage: "pip", description: Text("Resolve a link to start PiP playback."))
                .frame(minHeight: 220)
        }
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Video Link")
                .font(.headline)
            TextField("https://youtube.com/watch?v=...", text: $model.videoURLText)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button {
                    Task { await model.resolveFromText() }
                } label: {
                    Label(resolveButtonTitle, systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.resolveState == .resolving)

                Button {
                    model.openClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
            }

            Button {
                model.openInBrowser()
            } label: {
                Label("Open Browser Fallback", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var resolverArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resolver Endpoint")
                .font(.headline)
            TextField("https://your-server.example.com/resolve", text: $model.resolverEndpointText)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.saveEndpoint() }
            Text("Endpoint contract: POST JSON {\"url\":\"...\"}; return {\"streams\":[{\"id\":\"...\",\"url\":\"https://...m3u8\",\"title\":\"...\",\"quality\":\"720p\"}]}")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var streamsArea: some View {
        if model.resolvedStreams.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                Text("Streams")
                    .font(.headline)
                ForEach(model.resolvedStreams) { stream in
                    Button {
                        model.play(stream: stream)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(stream.displayTitle)
                                    .lineLimit(1)
                                if stream.detail.isEmpty == false {
                                    Text(stream.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "play.circle")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private var browserArea: some View {
        if let url = model.browserURL {
            VStack(alignment: .leading, spacing: 10) {
                Text("Browser Fallback")
                    .font(.headline)
                BrowserView(url: url)
                    .frame(minHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var statusArea: some View {
        Text(model.message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resolveButtonTitle: String {
        model.resolveState == .resolving ? "Resolving" : "Resolve & Play"
    }
}
