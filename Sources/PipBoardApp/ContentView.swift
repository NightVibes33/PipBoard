import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    var body: some View {
        TabView {
            WatchView()
                .tabItem { Label("Watch", systemImage: "play.rectangle") }
            DownloadsView()
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
            BrowserTabView()
                .tabItem { Label("Browser", systemImage: "safari") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

private struct WatchView: View {
    @EnvironmentObject private var model: PlaybackModel
    @State private var isImportingFile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    playerArea
                    quickActions
                    streamsArea
                    statusArea
                }
                .padding()
            }
            .background(backgroundGradient)
            .navigationTitle("PipBoard")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isImportingFile = true
                    } label: {
                        Image(systemName: "folder")
                    }
                    .accessibilityLabel("Import local file")

                    Button {
                        model.openClipboard()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .accessibilityLabel("Paste and resolve clipboard")
                }
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.movie, .video, .audio, .mpeg4Movie, .quickTimeMovie]) { result in
                switch result {
                case .success(let url):
                    model.importLocalFile(url)
                case .failure(let error):
                    model.message = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    @ViewBuilder
    private var playerArea: some View {
        if let url = model.activeVideoURL {
            PiPPlayerView(url: url)
                .frame(minHeight: 260)
                .clipShape(.rect(cornerRadius: 24))
                .overlay(alignment: .topLeading) {
                    Label("Ready for PiP", systemImage: "pip")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .pipGlassControl()
                        .padding(12)
                }
        } else {
            ContentUnavailableView("Resolve a Video", systemImage: "pip", description: Text("Paste a platform link, direct stream, import a file, or open the browser fallback."))
                .frame(minHeight: 260)
                .pipGlassPanel()
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Link")
                .font(.headline)
            TextField("YouTube, TikTok, X, Instagram, Reddit, MP4, M3U8...", text: $model.videoURLText)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button {
                    Task { await model.resolveFromText() }
                } label: {
                    Label(resolveButtonTitle, systemImage: "sparkles.tv")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.resolveState == .resolving)

                Button {
                    model.openInBrowser()
                } label: {
                    Image(systemName: "safari")
                        .frame(width: 42, height: 28)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Open browser fallback")
            }
        }
        .pipGlassPanel()
    }

    @ViewBuilder
    private var streamsArea: some View {
        if model.resolvedStreams.isEmpty == false {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Resolved Streams")
                        .font(.headline)
                    Spacer()
                    Text("\(model.resolvedStreams.count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .pipGlassControl()
                }

                ForEach(model.resolvedStreams) { stream in
                    StreamRow(stream: stream)
                }
            }
            .pipGlassPanel()
        }
    }

    private var statusArea: some View {
        Text(model.message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var resolveButtonTitle: String {
        model.resolveState == .resolving ? "Resolving" : "Resolve & Play"
    }
}

private struct StreamRow: View {
    @EnvironmentObject private var model: PlaybackModel
    let stream: ResolvedStream

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(stream.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    if stream.detail.isEmpty == false {
                        Text(stream.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    model.play(stream: stream)
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task { await model.download(stream: stream) }
                } label: {
                    Label("Download", systemImage: "arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(stream.isDownloadable == false)

                Button {
                    model.copy(stream: stream)
                } label: {
                    Image(systemName: "link")
                        .frame(width: 34, height: 28)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Copy stream URL")
            }
        }
        .padding(12)
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
    }
}

private struct DownloadsView: View {
    @EnvironmentObject private var model: PlaybackModel

    var body: some View {
        NavigationStack {
            List {
                if model.downloads.isEmpty {
                    ContentUnavailableView("No Downloads", systemImage: "arrow.down.circle", description: Text("Download MP4/progressive streams or import local media files."))
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(model.downloads) { download in
                        Button {
                            model.play(download: download)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.square.stack")
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(download.title)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text(download.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: model.deleteDownloads)
                }
            }
            .navigationTitle("Downloads")
            .safeAreaInset(edge: .bottom) {
                if case .downloading(let title) = model.downloadState {
                    Label("Downloading \(title)", systemImage: "arrow.down.circle")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .pipGlassControl()
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

private struct BrowserTabView: View {
    @EnvironmentObject private var model: PlaybackModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    TextField("https://site.com/video", text: $model.videoURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    Button {
                        model.openInBrowser()
                    } label: {
                        Image(systemName: "arrow.forward")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                if let url = model.browserURL {
                    BrowserView(url: url)
                        .clipShape(.rect(cornerRadius: 20))
                        .padding(.horizontal)
                } else {
                    ContentUnavailableView("Browser Fallback", systemImage: "safari", description: Text("Open sites here when direct stream resolution is not available."))
                        .pipGlassPanel()
                        .padding()
                }
            }
            .navigationTitle("Browser")
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: PlaybackModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Resolver")
                            .font(.headline)
                        TextField("https://your-server.example.com/resolve", text: $model.resolverEndpointText)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { model.saveEndpoint() }
                        Button {
                            model.saveEndpoint()
                        } label: {
                            Label("Save Endpoint", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .pipGlassPanel()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Endpoint Contract")
                            .font(.headline)
                        Text("POST JSON with a url field. Return streams or yt-dlp-style formats with direct AVPlayer-playable URLs. For downloads, return MP4/progressive file URLs instead of HLS manifests.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .pipGlassPanel()
                }
                .padding()
            }
            .navigationTitle("Settings")
        }
    }
}

private var backgroundGradient: some View {
    LinearGradient(
        colors: [Color.indigo.opacity(0.18), Color.teal.opacity(0.12), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
}
