# Omarchy Theme Marketplace

The website for [themes.omarchy.org](https://themes.omarchy.org): browse, preview and install community themes for [Omarchy](https://omarchy.org).

Themes are registered, validated and published by [omacom/omarchy-theme-registry](https://github.com/omacom/omarchy-theme-registry); this app fetches `catalog.json` from the CDN, caches it for five minutes, and falls back to the committed snapshot in `data/catalog.json` if the CDN is unreachable.

## Running locally

Requires Ruby 3.4 (see `.ruby-version`; `mise install` sets it up).

```sh
bundle install
bin/dev            # Rails on http://localhost:3000 + Tailwind watcher
bin/rails test
bundle exec rubocop
```

Environment:

| Variable       | Purpose                                                                                       | Default                          |
| -------------- | --------------------------------------------------------------------------------------------- | -------------------------------- |
| `CDN_BASE_URL` | Base URL of the registry CDN; `/v1/catalog.json` is appended                                  | `https://cdn.themes.omarchy.org` |
| `CATALOG_URL`  | Full catalog URL, overrides `CDN_BASE_URL` (test env sets it to nil to use the snapshot only) | derived                          |

Copy `.env.example` to `.env` for local development.

To refresh the local catalog snapshot: `curl -s "$CDN_BASE_URL/v1/catalog.json" -o data/catalog.json`.
