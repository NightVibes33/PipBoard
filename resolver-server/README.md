# PipBoard Resolver Server

This optional resolver uses `yt-dlp` to turn platform links into direct streams that PipBoard can play in AVKit PiP.

## Requirements

- Node.js 20+
- `yt-dlp` on PATH

## Run

```sh
PORT=8787 node server.mjs
```

Set PipBoard's resolver endpoint to:

```text
http://YOUR-LAN-IP:8787/resolve
```

For downloads, prefer formats that are MP4/progressive. HLS `.m3u8` streams play well in PiP but are not saved as one offline video file by the app.
