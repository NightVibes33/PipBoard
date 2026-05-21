# PipBoard

PipBoard is an iOS 26 SwiftUI app scaffold for sideloaded users who want to resolve video links into Picture in Picture playback.

It supports two playback paths:

- Direct media URLs play locally with AVKit PiP: `.mp4`, `.mov`, `.m4v`, `.m3u8`, and other AVPlayer-compatible URLs.
- Platform URLs such as YouTube, TikTok, X/Twitter, Instagram, Reddit, Twitch, and others can be resolved through a configurable remote resolver endpoint, then played in AVKit PiP when the resolver returns a playable stream.

Important platform limits:

- iOS does not allow a normal app to capture any other app and put it into PiP in real time.
- PiP is available for video content owned by the app or streams fed into AVPlayer.
- Whole-screen capture requires explicit user consent through ReplayKit and cannot bypass protected content, DRM, app sandboxing, or system privacy controls.
- An unsigned IPA can be built for the `iphoneos` SDK, but a stock real iPhone still needs signing before installation.

## Resolver Endpoint

For broad platform support, run a backend powered by `yt-dlp` or a compatible extractor. Configure its URL in the app.

PipBoard sends:

```json
{
  "url": "https://www.youtube.com/watch?v=..."
}
```

The endpoint should return:

```json
{
  "title": "Example video",
  "streams": [
    {
      "id": "720p",
      "title": "Example video",
      "url": "https://example.com/playlist.m3u8",
      "quality": "720p",
      "mimeType": "application/vnd.apple.mpegurl",
      "isLive": false
    }
  ]
}
```

The `url` must be directly playable by `AVPlayer`, preferably HLS `.m3u8` or MP4.

## Build locally on macOS

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project PipBoard.xcodeproj -scheme PipBoard -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO archive -archivePath build/PipBoard.xcarchive
mkdir -p build/Payload
cp -R build/PipBoard.xcarchive/Products/Applications/PipBoard.app build/Payload/
(cd build && zip -qry PipBoard-unsigned.ipa Payload)
```

## GitHub Actions

Push this repo to GitHub and run the `Build unsigned iOS IPA` workflow. The artifact will be named `PipBoard-unsigned-ipa`.
