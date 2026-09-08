# Catalog API

The marketplace is built on a static, versioned catalog published by [omacom/omarchy-theme-registry](https://github.com/omacom/omarchy-theme-registry). It is plain JSON on a CDN, so anything — this site, the Omarchy client, your own tooling — can read it without a database or an API key.

| Path | Purpose |
| --- | --- |
| `/v1/catalog.json` | Every listed theme with palette, mode, hue, preview, author, license, stars and the validated commit. |
| `/v1/catalog.min.json` | Slug, name, mode, hue, thumbnail, accent, background and install command. Small enough for a first paint. |
| `/v1/themes/<slug>.json` | One theme. |
| `/v1/catalog.json.sha256` | Integrity hash of `catalog.json`. |
| `/v1/previews/<slug>/<commit>/1200.webp` | 1200×675 preview, immutable per validated commit. `480.webp` is the thumbnail. |

The base URL is currently a development host and will move to `cdn.themes.omarchy.org` for production; the paths will not change. Responses carry `Cache-Control` (5 minutes for JSON, one year for previews) and `Access-Control-Allow-Origin: *`.

## Entry shape

```json
{
  "slug": "nujabes",
  "name": "Nujabes",
  "repo": "https://github.com/HalmyLyseas/omarchy-nujabes-theme",
  "author": { "login": "HalmyLyseas", "url": "https://github.com/HalmyLyseas" },
  "description": "A Nujabes tribute theme for Omarchy",
  "license": "MIT",
  "mode": "dark",
  "hue": "purple",
  "colors": { "accent": "#b26ac6", "background": "#0d0a11", "...": "..." },
  "generation": "native",
  "ignored_on_install": [],
  "backgrounds": { "count": 1, "has_video": false, "total_bytes": 1081450 },
  "preview": { "src": "…/1200.webp", "thumb": "…/480.webp", "width": 1200, "height": 675, "placeholder": "#080808" },
  "commit": "255b298d05db1ca186d8f0470d00d30356966774",
  "pushed_at": "2026-08-30T10:12:00Z",
  "stars": 51,
  "added_at": "2026-09-07",
  "tags": [],
  "featured": false,
  "warnings": ["REPO_NO_TOPIC"],
  "install": "omarchy theme install https://github.com/HalmyLyseas/omarchy-nujabes-theme"
}
```

`schema_version` is `1`. Breaking changes will publish under a new `/v2/` prefix; `/v1/` keeps working.
