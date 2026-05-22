import { createServer } from 'node:http';
import { execFile } from 'node:child_process';

const port = Number(process.env.PORT || 8787);
const ytdlp = process.env.YTDLP || 'yt-dlp';
const maxBodyBytes = 1024 * 64;
const authToken = process.env.RESOLVER_TOKEN || "";

function readBody(request) {
  return new Promise((resolve, reject) => {
    let body = '';
    request.on('data', chunk => {
      body += chunk;
      if (body.length > maxBodyBytes) {
        request.destroy();
        reject(new Error('Request body too large'));
      }
    });
    request.on('end', () => resolve(body));
    request.on('error', reject);
  });
}

function runYtdlp(url) {
  return new Promise((resolve, reject) => {
    execFile(
      ytdlp,
      ['--dump-single-json', '--no-playlist', '--no-warnings', url],
      { timeout: 90000, maxBuffer: 1024 * 1024 * 20 },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error(stderr.trim() || error.message));
          return;
        }
        resolve(JSON.parse(stdout));
      }
    );
  });
}

function streamFromFormat(format, title) {
  if (!format?.url) return null;
  const protocol = String(format.protocol || '');
  const ext = String(format.ext || '');
  const playableProtocol = protocol.startsWith('http') || protocol.includes('m3u8');
  const playableExt = ['mp4', 'm4v', 'mov', 'm3u8', 'mp3', 'm4a', 'aac'].includes(ext) || ext === 'unknown_video';
  if (!playableProtocol || !playableExt) return null;

  const height = format.height ? `${format.height}p` : null;
  const audioOnly = format.vcodec === 'none' ? 'audio' : null;
  const quality = height || format.resolution || audioOnly || format.format_note || format.format_id;
  return {
    id: String(format.format_id || format.url),
    title,
    url: format.url,
    quality,
    mimeType: format.mime_type || mimeTypeForExt(ext),
    isLive: Boolean(format.is_live) || protocol.includes('m3u8')
  };
}

function mimeTypeForExt(ext) {
  switch (ext) {
    case 'm3u8': return 'application/vnd.apple.mpegurl';
    case 'mp4':
    case 'm4v': return 'video/mp4';
    case 'mov': return 'video/quicktime';
    case 'mp3': return 'audio/mpeg';
    case 'm4a': return 'audio/mp4';
    case 'aac': return 'audio/aac';
    default: return null;
  }
}

function toResolverResponse(info) {
  const title = info.title || info.fulltitle || info.webpage_url || 'Video';
  const formats = Array.isArray(info.formats) ? info.formats : [];
  const streams = formats
    .map(format => streamFromFormat(format, title))
    .filter(Boolean)
    .sort((a, b) => score(b) - score(a));

  if (streams.length === 0 && info.url) {
    streams.push({
      id: String(info.id || info.url),
      title,
      url: info.url,
      quality: info.height ? `${info.height}p` : info.format_id || null,
      mimeType: mimeTypeForExt(info.ext),
      isLive: Boolean(info.is_live)
    });
  }

  return { title, streams };
}

function score(stream) {
  const quality = String(stream.quality || '');
  const height = Number((quality.match(/(\d+)p/) || [])[1] || 0);
  const isHls = String(stream.mimeType || '').includes('mpegurl') ? 5000 : 0;
  const isMp4 = String(stream.mimeType || '').includes('mp4') ? 3000 : 0;
  return isHls + isMp4 + height;
}

function send(response, status, payload) {
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'content-type, x-pipboard-token'
  });
  response.end(JSON.stringify(payload));
}

createServer(async (request, response) => {
  const requestURL = new URL(request.url || "/", "http://localhost");
  if (request.method === "GET" && requestURL.pathname === "/health") {
    send(response, 200, { ok: true });
    return;
  }

  if (request.method === 'OPTIONS') {
    send(response, 204, {});
    return;
  }

  if (request.method !== "POST" || requestURL.pathname !== "/resolve") {
    send(response, 404, { error: 'Use POST /resolve with {"url":"..."}' });
    return;
  }

  if (authToken && request.headers["x-pipboard-token"] !== authToken && requestURL.searchParams.get("token") !== authToken) {
    send(response, 401, { error: "Unauthorized" });
    return;
  }

  try {
    const body = await readBody(request);
    const { url } = JSON.parse(body || '{}');
    if (!url || !/^https?:\/\//i.test(url)) {
      send(response, 400, { error: 'A valid http(s) url is required' });
      return;
    }

    const info = await runYtdlp(url);
    const payload = toResolverResponse(info);
    if (payload.streams.length === 0) {
      send(response, 422, { error: 'No playable streams found' });
      return;
    }
    send(response, 200, payload);
  } catch (error) {
    send(response, 500, { error: error.message || String(error) });
  }
}).listen(port, '0.0.0.0', () => {
  console.log(`PipBoard resolver listening on http://0.0.0.0:${port}/resolve`);
});
