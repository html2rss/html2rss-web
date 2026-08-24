# Registry go-live manual

Step-by-step guide to ship and operate signed `registry.v1` bundles across the html2rss org repos.

**Related docs**

- Bundle format: [`html2rss/lib/html2rss/registry/README.md`](../../html2rss/lib/html2rss/registry/README.md)
- Operator runbook (sync flags, custom registries): [README.md — Registry sync runbook](./README.md#registry-sync-runbook)

---

## 1. Maintainers — merge and release order

Work in this order when a change touches registry contracts or feed configs.

### 1.1 `html2rss` (core gem)

Source of truth for `registry.v1` schema, `Html2rss::Registry::Verifier`, `CatalogBuilder`, and archive limits.

1. Merge registry-related changes to `main`.
2. Regenerate schema if config schema changed:
   ```bash
   cd html2rss
   mise exec -- make ready
   ```
3. Tag/release the gem when the contract is stable (web depends on this).

### 1.2 `html2rss-configs` (signed bundle publisher)

Source of truth for feed YAML and signed release artifacts.

1. Merge config changes to `master`.
2. Run the configs quality gate:
   ```bash
   cd html2rss-configs
   make ready
   ```
3. Tag the release (tag name becomes `manifest.json` `version` in CI via `REGISTRY_VERSION: ${{ github.ref_name }}`):
   ```bash
   git tag v2026.08.22   # example; use your release tag
   git push origin v2026.08.22
   ```
4. Tag push triggers [`.github/workflows/release.yml`](../../html2rss-configs/.github/workflows/release.yml):
   - `make registry-build -- --sign`
   - uploads `dist/registry-bundle.tar.gz` to a **draft** GitHub Release (human publishes after review)

**Draft → publish:** CI creates a draft release. Maintainers review the asset, release notes, and tag diff, then click **Publish release** in GitHub. Draft releases are invisible to `/releases/latest` until published.

### 1.3 `html2rss-web` (runtime + Docker image)

Consumes verified bundles; bakes the official release bundle into the Docker image at build time.

1. Bump the `html2rss` gem dependency if the core contract changed.
2. Update `config/registries.yml` when the signing key or sync channel changes (see sections 2 and 5).
3. Build the image with the official release artifact baked (section 3).
4. Merge to `main`, wait for CI (`ci` workflow) to pass.
5. Publish a GitHub Release on `html2rss-web` — [`.github/workflows/release.yml`](../../html2rss-web/.github/workflows/release.yml) builds and pushes `html2rss/web` tags (`latest`, semver, major, commit SHA).

**Rule of thumb:** core contract → configs signed release → web image that embeds/verifies that release.

---

## 2. First signed release — signing key, tag, verify artifact

### 2.1 Generate an Ed25519 key pair

Use OpenSSL (same algorithm as `tool/registry-build` and `Html2rss::Registry::Verifier`):

```bash
openssl genpkey -algorithm ED25519 -out registry-signing.pem
openssl pkey -in registry-signing.pem -pubout -out registry-signing.pub
```

Keep the private key offline except where signing happens.

### 2.2 Configure `html2rss-configs` CI secrets

In the `html2rss-configs` GitHub repo, add secrets on the **`registry-release`** environment:

| Secret | Purpose |
| --- | --- |
| `REGISTRY_SIGNING_KEY` | Full PEM contents of `registry-signing.pem` (private key; used by `make registry-build -- --sign`) |
| `REGISTRY_PUBLIC_KEY_PEM` | Full PEM contents of `registry-signing.pub` (public key; used by the release verify step — not a repo fixture) |

Release CI reads them here:

```yaml
env:
  REGISTRY_VERSION: ${{ github.ref_name }}
  REGISTRY_SIGNING_KEY: ${{ secrets.REGISTRY_SIGNING_KEY }}
run: make registry-build -- --sign
```

The verify step loads the public key from `REGISTRY_PUBLIC_KEY_PEM` in-process (`OpenSSL::PKey.read(ENV.fetch('REGISTRY_PUBLIC_KEY_PEM'))`); no committed PEM file in the configs repo.

At go-live, the same public key must appear in `html2rss-web/config/registries.yml` (`public_key` / `public_key_id`) so runtime sync verification matches CI.

### 2.3 Pin the public key in `html2rss-web`

Add the public key to `config/registries.yml` before instances need to sync signed bundles over the network:

```yaml
registries:
  official:
    sync:
      channel: html2rss-official
      pin_version: v2026.08.22   # optional: fetch this tag only
      max_version: v2026.08.22   # optional: reject newer manifests (incident freeze)
    auto_promote: false          # default false; verified bundles stage until manual promote
    catalog: true
    public_key_id: html2rss:registry:2026
    public_key: |
      -----BEGIN PUBLIC KEY-----
      ...
      -----END PUBLIC KEY-----
    allowed_channel_domains:     # optional suffix allowlist for channel.url domains
      - anthropic.com
      - github.com
```

- `public_key_id` must match the value in signed `manifest.json` (default in `tool/registry-build`: `html2rss:registry:2026`).
- Network sync and embedded bundle loading use `:signed` trust and require this pin. Local `path:` mounts use `:integrity_only` trust (no signature check on load).
- **`auto_promote: false`** (default) writes verified bundles to `REGISTRY_DATA_ROOT/<id>/.staging/` without changing the active catalog. Promote after review with `bin/html2rss-web registry promote --registry official`.
- **`pin_version`** resolves the GitHub tag release API instead of `/releases/latest`.
- **`max_version`** rejects sync when the verified manifest version is newer than the cap (incident freeze).
- **`allowed_channel_domains`** rejects bundle load when any config `channel.url` host is outside the suffix allowlist.

### 2.4 Tag and publish the configs release

```bash
cd html2rss-configs
git tag <version>    # e.g. 2026.08.22
git push origin <version>
```

Wait for the Release workflow to finish. The asset name is always **`registry-bundle.tar.gz`**.

### 2.5 Verify the release artifact

Download the asset from the GitHub Release, then verify locally:

```bash
mkdir -p /tmp/registry-verify && tar -xzf registry-bundle.tar.gz -C /tmp/registry-verify

# Inspect manifest
jq . /tmp/registry-verify/manifest.json
# Confirm: format=registry.v1, registry_id=official, version=<tag>, public_key_id matches pin

# Confirm signature file exists
test -f /tmp/registry-verify/manifest.sig

# Optional: verify with core gem (from html2rss checkout)
cd html2rss
mise exec -- bundle exec ruby -rhtml2rss -ropenssl -e "
  pk = OpenSSL::PKey.read(File.read('path/to/registry-signing.pub'))
  Html2rss::Registry::Verifier.verify!(
    '/tmp/registry-verify',
    trust: :signed,
    public_keys: { 'html2rss:registry:2026' => pk }
  )
  puts 'OK'
"
```

Unsigned local builds (no `--sign`) are valid for integrity-only use only:

```bash
cd html2rss-configs
make registry-build    # writes dist/registry-bundle.tar.gz without manifest.sig
```

---

## 3. Web image build — artifact baking and Docker

### 3.1 How the official registry gets into the image

| Step | What happens |
| --- | --- |
| `Dockerfile` (`registry-builder`) | Downloads the official release `registry-bundle.tar.gz`, extracts it, and verifies its Ed25519 signature & file digests against `config/registries.yml` |
| `Dockerfile` (Runtime) | `COPY --from=registry-builder /build/official /app/registries/official` |
| Boot | `Registry::Index.current` loads `/app/registries/official` directly. Zero copying, zero network calls. |

### 3.2 Build locally

To build a production image fetching the latest official release:

```bash
cd html2rss-web
docker build -t html2rss/web -f Dockerfile .
```

To build pinning a specific configs release tag:

```bash
docker build \
  --build-arg REGISTRY_RELEASE_TAG=v2026.08.22 \
  --build-arg REGISTRY_BUNDLE_URL=https://github.com/html2rss/html2rss-configs/releases/download/v2026.08.22/registry-bundle.tar.gz \
  --build-arg BUILD_TAG=1.2.3 \
  --build-arg GIT_SHA="$(git rev-parse HEAD)" \
  -t html2rss/web \
  -f Dockerfile .
```

### 3.3 What operators get in the image

- **`/app/registries/official/`** — Pre-verified official release bundle baked at build time (immutable image layer).
- **`/app/config/registries.yml`** — Default official registry configuration with pinned public key.
- **`/app/data/registries`** — Empty at build; used at runtime for network synchronization.

---

## 4. Operators — default path (official registry)

### 4.1 Pull a new image (simplest update path)

`docker-compose.yml` defaults:

- Image: `html2rss/web`
- Volume: `registry-data:/app/data/registries` (`REGISTRY_DATA_ROOT`)

```bash
docker compose pull html2rss-web
docker compose up -d html2rss-web
```

A new image updates the **embedded bundle** inside the container layers.

### 4.2 Zero-config first boot

With the stock `config/registries.yml`, no extra registry env vars are required.

On boot (`Registry::Sync.boot!`):

1. **Instant index** — loads directly from `/app/registries/official` (or `REGISTRY_DATA_ROOT/official` if an updated synced bundle exists).
2. **Sync on boot** — runs only when `REGISTRY_SYNC_ON_BOOT=true`.
3. **Background refresh** — when `REGISTRY_SYNC_INTERVAL_HOURS` > 0 (default **24**), re-syncs on a periodic timer. Set to `0` to disable.

Official sync URL (from `config/registries.yml` + `Registry::Config`):

`https://github.com/html2rss/html2rss-configs/releases/latest/download/registry-bundle.tar.gz`

Allowed outbound hosts (built-in): `api.github.com`, `github.com`, `objects.githubusercontent.com`.

### 4.3 Existing instance — volume retained

The named volume preserves runtime-synced bundles across container restarts. When present and valid, `Store.active_dir` prefers the volume copy over the embedded image copy.

- Old bundle stays active until a successful sync swaps it.
- Use `bin/html2rss-web registry sync` or wait for background refresh to pick up a new configs release without rebuilding the image (section 7).

---

## 5. Operators — custom corporate registry

Override or extend `config/registries.yml` (or set `REGISTRIES_CONFIG` to an alternate file path).

Example from the [registry sync runbook](./README.md#add-a-corporate-registry):

```yaml
precedence:
  - official
  - corp

registries:
  official:
    sync:
      channel: html2rss-official
    catalog: true
    public_key_id: html2rss:registry:2026
    public_key: |
      -----BEGIN PUBLIC KEY-----
      ...
      -----END PUBLIC KEY-----

  corp:
    sync:
      url: https://registry.example.com/registry-bundle.tar.gz
    catalog: false
    public_key_id: corp:registry:2026
    public_key: |
      -----BEGIN PUBLIC KEY-----
      ...
      -----END PUBLIC KEY-----
```

| Field | Purpose |
| --- | --- |
| `precedence` | Feed lookup merge order; first match wins |
| `sync.url` | Direct HTTPS tarball URL for network sync |
| `sync.channel: html2rss-official` | Resolves to the official GitHub release asset |
| `catalog: false` | Feeds served at `/{feed_id}.rss`; **omitted** from `GET /api/v1/configs` |
| `public_key` / `public_key_id` | Required for `:signed` network sync verification |

For hosts outside the default GitHub allowlist:

```bash
REGISTRY_SYNC_ALLOWED_HOSTS=registry.example.com,cdn.example.com
```

Mount a custom registries file in Compose:

```yaml
volumes:
  - ./config/registries.yml:/app/config/registries.yml:ro
```

---

## 6. Verify live

Run these checks after deploy or sync.

### 6.1 Registry sync status (CLI)

Inside the running container (or Dev Container):

```bash
bin/html2rss-web registry status
```

Tab-separated columns: `registry`, `mode`, `version`, `staged_version`, `updated_at`, `sync_url`, `last_error`.

- Exit code **0** — all sync-mode registries have a usable on-disk bundle.
- Exit code **1** — at least one sync registry lacks a bundle (see `Registry::Sync.unusable_sync_registries`).

Single registry, dry-run, or promote staged bundle:

```bash
bin/html2rss-web registry sync --registry official
bin/html2rss-web registry sync --registry official --dry-run
bin/html2rss-web registry promote --registry official
```

### 6.2 Instance metadata API

```bash
curl -sS http://127.0.0.1:4000/api/v1/ | jq '.data.instance'
```

Confirm:

- **`instance.registries`** — array with `id`, `version`, `updated_at`, `sync_mode` per configured registry
- **`instance.catalog`** — `{ "enabled": true, "url": ".../api/v1/configs" }` (unless `CONFIG_CATALOG_ENABLED=false`)

### 6.3 Catalog API

```bash
curl -sS http://127.0.0.1:4000/api/v1/configs | jq '.data.configs[0]'
```

Expect rows with `source: "registry"`, `registry: "official"`, and a `path` like `/anthropic.com/news.rss`.

When `CONFIG_CATALOG_ENABLED=false`, expect `404` with `{ "error": "catalog_disabled" }`.

### 6.4 Sample static feed

Pick a feed id from the catalog (`id` field) or from `configs/<id>.yml` in the bundle. Request:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:4000/anthropic.com/news.rss
```

Expect HTTP **200** and valid RSS XML.

---

## 7. Update configs without pulling a new Docker image

Configs releases are independent of web image releases. To refresh feeds on a running instance:

### 7.1 Manual sync and promote

Production recommendation: keep `auto_promote: false`, set `sync.pin_version` to the approved tag, fetch with sync, then promote manually after review.

```bash
bin/html2rss-web registry sync --registry official
bin/html2rss-web registry status          # staged_version shows verified bundle
bin/html2rss-web registry promote --registry official
```

Fetches the pinned or latest signed tarball, verifies signature + digests, and either stages (`auto_promote: false`) or atomically swaps the active bundle (`auto_promote: true`).

### 7.2 Incident freeze

To block uptake of a newer configs release without disabling sync entirely:

```yaml
registries:
  official:
    sync:
      channel: html2rss-official
      max_version: v2026.08.21
    auto_promote: false
```

Set `REGISTRY_SYNC_INTERVAL_HOURS=0` to pause background refresh while investigating.

### 7.3 Automatic refresh via Docker Compose

In production Compose environments, registry synchronization is handled cleanly outside the Ruby/Puma process lifecycle via the dedicated `registry-sync` Compose service in `docker-compose.yml`:

```yaml
  registry-sync:
    image: html2rss/web
    restart: unless-stopped
    command: ["sh", "-c", "while true; do html2rss-web registry sync; sleep $${REGISTRY_SYNC_INTERVAL_SECONDS:-86400}; done"]
    environment:
      REGISTRY_DATA_ROOT: /app/data/registries
      REGISTRY_SYNC_INTERVAL_SECONDS: 86400
    volumes:
      - registry-data:/app/data/registries
```

When new bundles are synced to disk, the `html2rss-web` server detects the updated `manifest.json` mtimes automatically on subsequent requests.

To run an on-demand sync or check status with Docker Compose:

```bash
docker compose exec html2rss-web html2rss-web registry status
docker compose exec html2rss-web html2rss-web registry sync --registry official
```

---

## 8. Troubleshooting

### 8.1 Signature verification failure

Symptoms in `bin/html2rss-web registry status`:

- `last_error` contains `Unknown public_key_id`, `Invalid manifest signature`, or `Missing manifest.sig`

Checks:

1. `public_key_id` and `public_key` in `registries.yml` match the signed release.
2. Deploy web config **before** or **with** the first bundle signed by a new key (key rotation).
3. Downloaded asset is `registry-bundle.tar.gz` from the expected release (not an unsigned local build).

Signature-related failures are logged via `SecurityLogger.log_registry_signature_failure`.

Verify without swapping the active bundle:

```bash
bin/html2rss-web registry sync --registry official --dry-run
```

### 8.2 Sync failure keeps the old bundle

By design:

- `Registry::Sync.run` only calls `Store.swap!` after fetch **and** verification succeed.
- On failure, `last_error` is recorded; the previous bundle under `REGISTRY_DATA_ROOT/<registry_id>/` remains served.
- `Store.promote_bundle!` rolls back on swap failure.

If sync fails on first boot with no prior bundle in the volume, the instance serves the embedded official bundle (140+ feeds) directly from the container image.

### 8.3 Network / host errors

| Error pattern | Likely cause |
| --- | --- |
| `Registry sync host not allowed` | Add host to `REGISTRY_SYNC_ALLOWED_HOSTS` |
| `Registry sync rejects HTTP redirects` | Publish a direct HTTPS asset URL (`sync.url`) |
| `Registry sync fetch failed with HTTP …` | Release missing, URL wrong, or GitHub outage |
| `Registry sync requires HTTPS URLs` | Use `https://` in `sync.url` |

Default allowed hosts cover official GitHub release downloads (`api.github.com`, `github.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com`).

### 8.4 Air-gapped / offline (`path` mode)

For environments without outbound sync, mount a verified bundle directory and skip network sync:

```yaml
registries:
  official:
    path: /opt/html2rss/registry/official
    catalog: true
```

Requirements:

- Directory contains `manifest.json`, `configs/`, and optionally `manifest.sig`
- `bin/html2rss-web registry sync` is not applicable (`path mode; sync is not applicable`)
- `bin/html2rss-web registry status` should show `mode: path`

Load path uses `:integrity_only` trust (disk/image trust boundary).

In Docker Compose, bind-mount the bundle and optionally set `REGISTRIES_CONFIG`:

```yaml
volumes:
  - /opt/html2rss/registry/official:/opt/html2rss/registry/official:ro
environment:
  REGISTRIES_CONFIG: /app/config/registries.yml
```

### 8.5 CLI exit code non-zero with empty `last_error`

`bin/html2rss-web registry status` exits **1** when a sync-mode registry has **no usable bundle** (neither in the volume nor embedded in the image). Run a sync or verify the embedded bundle is present:

```bash
bin/html2rss-web registry sync --registry official
bin/html2rss-web registry status
```

