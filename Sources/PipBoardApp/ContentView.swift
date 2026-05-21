import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: PlaybackModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let url = model.activeVideoURL {
                    PiPPlayerView(url: url)
                        .frame(minHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ContentUnavailableView("No Video Loaded", systemImage: "pip", description: Text(model.message))
                        .frame(minHeight: 260)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Video URL")
                        .font(.headline)
                    TextField("https://example.com/video.m3u8", text: $model.videoURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    Button {
                        model.playFromText()
                    } label: {
                        Label("Open in Player", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text(model.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
            .navigationTitle("PipBoard")
        }
    }
}
