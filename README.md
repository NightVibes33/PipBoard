# PipBoard

PipBoard is an iOS 26 SwiftUI app for sideloaded users who want to resolve video links into Picture in Picture playback, save supported streams, and keep a local media library.

## What It Can Do

- Play direct media URLs locally with AVKit PiP: `.mp4`, `.mov`, `.m4v`, `.m3u8`, `.mp3`, `.aac`, and `.m4a`.
- Resolve platform URLs such as YouTube, TikTok, X/Twitter, Instagram, Reddit, Twitch, and others through a configurable remote resolver endpoint.
- Decode both PipBoard's `streams` response format and common `yt-dlp`-style `formats` responses.
- Download progressive file streams such as MP4/MOV/audio into the app's local library.
- Share, delete, or clear downloaded files from the local library.
- Import local media files from Files and keep them in the downloads library.
- Copy resolved stream URLs for debugging or external use.
- Open web pages in the built-in browser fallback with back, forward, reload, and stop controls when stream resolution fails.
- Accept links from the iOS share sheet as URL or plain text, including text that contains a link.

## Platform Limits

- iOS does not allow a normal app to capture any other app and put it into PiP in real time.
- PiP is available for video content owned by the app or streams fed into AVPlayer.
- HLS `.m3u8` streams play well, but the app does not package HLS segments into offline files. For downloads, have the resolver return MP4/progressive URLs.
- An unsigned IPA can be built for the `iphoneos` SDK, but a stock real iPhone still needs signing before installation.

## Resolver Endpoint

For broad platform support, run a backend powered by `yt-dlp` or a compatible extractor. A minimal Node server is included in `resolver-server/`; it supports `/resolve`, `/health`, and optional `RESOLVER_TOKEN` auth.

PipBoard sends:

```json
{
  "url": "https://www.youtube.com/watch?v=..."
}
```

Preferred response:

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

The app also accepts a `formats` array with `yt-dlp`-style keys such as `format_id`, `height`, `resolution`, `ext`, `protocol`, `mime_type`, and `url`.

## Build Locally On macOS

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
