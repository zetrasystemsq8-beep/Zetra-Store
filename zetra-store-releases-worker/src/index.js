export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/health') {
      return new Response('OK', { status: 200 });
    }

    if (request.method === 'POST' && url.pathname === '/upload-apk') {
      return handleUpload(request, env);
    }

    return json({ error: 'Not found' }, 404);
  },
};

async function handleUpload(request, env) {
  const apiKey = request.headers.get('X-Api-Key');
  if (!apiKey || apiKey !== env.WORKER_API_KEY) {
    return json({ error: 'Unauthorized' }, 401);
  }

  const url = new URL(request.url);
  const appId = url.searchParams.get('appId');
  const versionName = url.searchParams.get('versionName');

  if (!appId || !versionName) {
    return json({ error: 'appId and versionName are required query params' }, 400);
  }

  const contentType =
    request.headers.get('Content-Type') || 'application/vnd.android.package-archive';
  const apkBytes = await request.arrayBuffer();

  if (apkBytes.byteLength === 0) {
    return json({ error: 'Empty request body — no APK data received' }, 400);
  }

  const tag = sanitize(`${appId}-v${versionName}`);
  const owner = env.GITHUB_OWNER;
  const repo = env.GITHUB_REPO;
  const ghHeaders = {
    Authorization: `Bearer ${env.GITHUB_TOKEN}`,
    Accept: 'application/vnd.github+json',
    'User-Agent': 'zetra-store-releases-worker',
  };

  try {
    let release = await getReleaseByTag(owner, repo, tag, ghHeaders);
    if (!release) {
      release = await createRelease(owner, repo, tag, appId, versionName, ghHeaders);
    }

    const uploadUrl = release.upload_url.replace('{?name,label}', '');
    const fileName = `${sanitize(appId)}-${sanitize(versionName)}-${Date.now()}.apk`;

    const assetRes = await fetch(`${uploadUrl}?name=${encodeURIComponent(fileName)}`, {
      method: 'POST',
      headers: {
        ...ghHeaders,
        'Content-Type': contentType,
        'Content-Length': String(apkBytes.byteLength),
      },
      body: apkBytes,
    });

    if (!assetRes.ok) {
      const errText = await assetRes.text();
      return json({ error: 'GitHub asset upload failed', detail: errText }, 502);
    }

    const asset = await assetRes.json();

    return json({
      downloadUrl: asset.browser_download_url,
      fileSizeBytes: asset.size,
      releaseTag: tag,
    });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
}

async function getReleaseByTag(owner, repo, tag, headers) {
  const res = await fetch(
    `https://api.github.com/repos/${owner}/${repo}/releases/tags/${encodeURIComponent(tag)}`,
    { headers },
  );
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Failed to look up release: ${res.status}`);
  return res.json();
}

async function createRelease(owner, repo, tag, appId, versionName, headers) {
  const res = await fetch(`https://api.github.com/repos/${owner}/${repo}/releases`, {
    method: 'POST',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      tag_name: tag,
      name: `${appId} v${versionName}`,
      body: `Automated release for app ${appId}, version ${versionName}.`,
      draft: false,
      prerelease: false,
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Failed to create release: ${res.status} ${errText}`);
  }
  return res.json();
}

function sanitize(value) {
  return value.toLowerCase().replace(/[^a-z0-9.\-]/g, '-');
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
