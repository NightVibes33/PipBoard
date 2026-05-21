# PipBoard

PipBoard is an iOS 26 SwiftUI app scaffold for opening shared video URLs and playing them in Picture in Picture.

Important platform limits:

- iOS does not allow a normal app to capture any other app and put it into PiP in real time.
- PiP is available for video content owned by the app through AVKit, or carefully managed sample-buffer playback.
- Whole-screen capture requires explicit user consent through ReplayKit and cannot bypass protected content, DRM, app sandboxing, or system privacy controls.
- An unsigned IPA can be built for the `iphoneos` SDK, but a stock real iPhone still needs signing with a valid provisioning profile before installation.

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
