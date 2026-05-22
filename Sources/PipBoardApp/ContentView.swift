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
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
    }
}

private struct WatchView: View {
    @EnvironmentObject private var model: PlaybackModel
    @StateObject private var browserState = BrowserState()
    @State private var isImportingFile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    linkBar
                    playerArea
                    streamsArea
                    statusArea
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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

    private var linkBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Paste a video link or direct stream", text: $model.videoURLText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                Button {
                    model.openInBrowser()
                } label: {
                    Image(systemName: "safari")
                        .frame(width: 34, height: 28)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Open web player")
            }

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
                    Image(systemName: "doc.on.clipboard")
                        .frame(width: 38, height: 28)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Paste clipboard")
            }
        }
        .pipGlassPanel(cornerRadius: 18)
    }

    @ViewBuilder
    private var playerArea: some View {
        if let url = model.activeVideoURL {
            PiPPlayerView(url: url)
                .frame(minHeight: 300)
                .clipShape(.rect(cornerRadius: 20))
                .overlay(alignment: .topLeading) {
                    Label("Native Player", systemImage: "pip")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .pipGlassControl()
                        .padding(12)
                }
        } else if let url = model.browserURL {
            VStack(spacing: 0) {
                BrowserControlBar(state: browserState, titleFallback: url.host ?? "Web Player")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                BrowserView(url: url, state: browserState)
            }
            .frame(minHeight: 420)
            .background(.thinMaterial, in: .rect(cornerRadius: 20))
            .clipShape(.rect(cornerRadius: 20))
        } else {
            ContentUnavailableView("Paste a Link", systemImage: "play.rectangle", description: Text("Direct media opens in the native player. Platform pages open here automatically."))
                .frame(minHeight: 300)
                .pipGlassPanel(cornerRadius: 20)
        }
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
                        HStack(spacing: 12) {
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
                            .buttonStyle(.plain)

                            Spacer()

                            ShareLink(item: download.localURL) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Share downloaded file")
                        }
                    }
                    .onDelete(perform: model.deleteDownloads)
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                if model.downloads.isEmpty == false {
                    Button(role: .destructive) {
                        model.clearDownloads()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Clear downloads")
                }
            }
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
private struct BrowserControlBar: View {
    @ObservedObject var state: BrowserState
    let titleFallback: String

    var body: some View {
        HStack(spacing: 10) {
            Button { state.goBack() } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.bordered)
                .disabled(state.canGoBack == false)
            Button { state.goForward() } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.bordered)
                .disabled(state.canGoForward == false)
            Button { state.isLoading ? state.stopLoading() : state.reload() } label: {
                Image(systemName: state.isLoading ? "xmark" : "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            Text(state.title.isEmpty ? titleFallback : state.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
    }
}

private struct BrowserTabView: View {
    @StateObject private var browserState = BrowserState()
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
                    BrowserControlBar(state: browserState, titleFallback: url.host ?? "Browser")
                        .padding(.horizontal)
                    BrowserView(url: url, state: browserState)
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
                        Text("Optional Resolver")
                            .font(.headline)
                        TextField("Optional yt-dlp endpoint", text: $model.resolverEndpointText)
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
                        Text("Leave this empty for direct streams and the built-in web player. Add a yt-dlp endpoint only if you want native playable streams or downloads for platform pages.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .pipGlassPanel()
                }
                .padding()
            }
            .navigationTitle("Advanced")
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
