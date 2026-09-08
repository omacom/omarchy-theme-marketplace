# Omarchy Theme Marketplace

The website for [themes.omarchy.org](https://themes.omarchy.org): browse, preview and install community themes for [Omarchy](https://omarchy.org). Ruby on Rails 8, Hotwire, Tailwind CSS 4.

The site is read-only over a published catalog. Themes are registered, validated and published by [omacom/omarchy-theme-registry](https://github.com/omacom/omarchy-theme-registry); this app fetches `catalog.json` from the CDN, caches it for five minutes, and falls back to the committed snapshot in `data/catalog.json` if the CDN is unreachable.

## Running locally

Requires Ruby 3.4 (see `.ruby-version`; `mise install` sets it up).

```sh
bundle install
bin/rails db:prepare
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

To refresh the snapshot: `curl -s "$CDN_BASE_URL/v1/catalog.json" -o data/catalog.json`.

## Layout

- `app/models/catalog.rb`, `theme.rb`, `theme_query.rb` — catalog loading, one theme, and the URL-param driven filter/search/sort/paging used by the gallery.
- `app/helpers/ui_helper.rb` — ports of the shadcn button/badge/card/input class builders so views stay pixel-identical to the design.
- `app/helpers/icons_helper.rb` — inline Remix icons.
- `app/views/home` — hero, gallery (a Turbo Frame; filters and search are plain GET links/forms), submit steps, stats.
- `app/views/themes/show` — theme page: preview, install command, palette, validation notes, more by author.
- `app/views/docs/pages/*.md` — documentation rendered with kramdown.
- `app/javascript/controllers` — Stimulus: `theme` (light/dark), `sheet` (mobile menu), `search` (debounced submit), `copy`, `like`.
- `app/assets/tailwind/application.css` — design tokens (Tokyo Night / Tokyo Night Day), fonts, base layer.

## Deploying

`config/deploy.yml` is a Kamal config for a single Digital Ocean droplet behind Cloudflare. Set `DEPLOY_HOST`, the registry credentials and `RAILS_MASTER_KEY` in `.kamal/secrets`, then `kamal setup` once and `kamal deploy` afterwards.
