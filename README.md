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

## Build an installable signed IPA on GitHub

The unsigned workflow proves the app compiles for `iphoneos`, but an unsigned IPA will not install on a normal real iPhone. For an installable IPA, add these repository secrets and run `Build signed iOS IPA` manually:

- `IOS_P12_BASE64`: Base64 encoded Apple signing certificate `.p12`.
- `IOS_P12_PASSWORD`: Password for that `.p12`.
- `KEYCHAIN_PASSWORD`: Temporary CI keychain password.
- `APPLE_TEAM_ID`: Your Apple Developer Team ID.
- `IOS_APP_PROFILE_BASE64`: Base64 encoded provisioning profile for the main app bundle id.
- `IOS_SHARE_PROFILE_BASE64`: Base64 encoded provisioning profile for the share extension bundle id.
- `IOS_BROADCAST_PROFILE_BASE64`: Base64 encoded provisioning profile for the broadcast extension bundle id.

The bundle IDs entered in the workflow dispatch form must match the three provisioning profiles.
