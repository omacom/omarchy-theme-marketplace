# Omarchy Theme Marketplace (site)

Rails app for **themes.omarchy.org**, the community theme marketplace for Omarchy (replaces `omarchy.org/themes`). It is a read-mostly front end over a static catalog that a separate repo publishes; the sibling repo `../omarchy-themes-registry` owns theme data, validation and the catalog build. `plan.md` (gitignored, local only) tracks follow-ups; the full architecture is in the ecosystem plan artifact.

## Working rules

- **Never `git commit` or `git push`.** Leave changes in the working tree and report them; the user reviews and commits. Applies to every repo in this project.
- Branch is `master`. The old SvelteKit version lives on `sveltekit-legacy`; do not touch it.
- **Do not add or rename colour tokens** in `app/assets/tailwind/application.css`. New UI adapts to the existing shadcn-style tokens (`--primary`, `--muted-foreground`, `--card`, …). Reuse the helpers in `app/helpers/ui_helper.rb` (`ui_button`, `ui_badge`, `ui_card`, `button_class`, `input_class`) instead of inventing new component classes; icons are inline Remix paths in `icons_helper.rb`.
- Never write the R2 dev URL (`pub-*.r2.dev`) into README, `.env.example`, the guide page or code. It belongs in `.env` (gitignored), `config/deploy.yml`, and CI variables only.
- No admin UI on the site. Maintainers work through the registry repo and GitHub. "Report a problem" links to the theme artist's issue tracker.
- Theme creators are called **artists** everywhere in this app's code and UI (`Theme#artist_login`/`#artist_url`, `Catalog#artists`/`#by_artist`, `ArtistsController`, `/artists/:login`). The published catalog JSON still names the field `author` — that's the registry's contract (`omarchy-theme-registry`), not something this repo controls, so `Theme#initialize` reads `data["author"]` but exposes it as `artist`.
- Install counts arrive together with the Omarchy CLI (Phase 5). Until then the site only counts install-command *copies*; never present copies as installs.
- If files change on disk from outside the session, say so and wait for instructions rather than fixing them.
- Visual checks (dev server + screenshots) are for structural or layout changes only, not small tweaks.
- Keep the design, theme and layout as they are unless asked; ERB templates must use `<%= %>` for helpers that render (`link_to`, `image_tag`), never `<% %>`.

## Stack

Rails 8.1 (Ruby 3.4, via mise), Propshaft + importmap, Turbo/Stimulus, `tailwindcss-rails` (Tailwind v4 standalone; `bin/dev` runs the watcher), SQLite with Solid Cache/Queue/Cable, Kamal to a Digital Ocean droplet, kramdown for the guide page. Gem pins that matter: `json < 3` (3.x breaks session cookie decoding), `dotenv-rails` in dev/test loads `.env`.

## How data flows

- `Catalog.current` fetches `#{CDN_BASE_URL}/v1/catalog.json`, caches it 5 minutes, and falls back to the snapshot `data/catalog.json` when the CDN is unreachable. Tests set `catalog_url = nil` so they always use the snapshot. Refresh the snapshot with `just snapshot`.
- `Theme` (`app/models/theme.rb`) is a read-only value object for one catalog entry: palette, mode, hue, preview URLs, validation `warnings` (codes mapped to labels), `new?`, `palette_rows`, and engagement stats via `Engagement`.
- `ThemeQuery` does filtering (featured/all/dark/light/hue), search, sorting (`name`, `new`, `trending`, `stars`) and paging, all from URL params so gallery states are shareable. The gallery is a Turbo Frame; `#gallery-state` inside the frame carries the current filter/sort for the hero search form.
- Engagement lives in the site DB: `users`/`sessions` (GitHub OAuth), `likes`, `command_copies` (per theme per day, from the theme page copy button via `POST /themes/:slug/copied`). `Engagement.all` caches the per-slug counts for a minute.
- Themes are submitted through the registry's GitHub issue form; `config.x.submit_url` is the one place that URL lives. The `/guide` page is one markdown file (`app/views/guide/pages/index.md`) rendered as sections with in-page anchors — no more multi-page docs nav. `GuideController::PAGES` allowlists it (`api` stays unlisted in `guide/pages/api.md` until the CDN moves to its production domain). There is no "Guide" link in the header; the "Submit a theme" button opens `guide_path` at the top, so a first-time visitor reads the whole flow before reaching the form. Site copy avoids GitHub-specific words like "issue" when describing submission — say "form" or "submission" instead.

## Hidden for v1 (built, switched off)

GitHub sign-in (`/login` renders a disabled button; header shows no sign-in link), the like button (`themes/_like_button`), the "Most liked" sort, and `/me`. `plan.md` lists exactly what to flip to turn them on. The OAuth flow needs `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET`.

## Commands

`just` lists everything. `just ci` runs `bin/ci` (rubocop, bundler-audit, importmap audit, Brakeman, tests, seeds), which is what `.github/workflows/ci.yml` runs. `just test`, `just lint`, `just fix`, `just migrate`, `just dev`.

Dev server for screenshots: use a spare port (`bin/rails server -p 3200 -d`), stop it with `lsof -ti :3200 | xargs kill -9` and `rm -f tmp/pids/server.pid` (a stale pid file blocks the next start). Playwright is available from the npx cache with an explicit Chromium `executablePath`; scripts must be CommonJS when relying on `NODE_PATH`.

## Environment

`CDN_BASE_URL` (default `https://cdn.themes.omarchy.org`; `CATALOG_URL` overrides the full URL), `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`. Local values go in `.env`; production values in `config/deploy.yml` (`env.clear`) and `.kamal/secrets`. `config/cable.yml` production still names Redis and must switch to `solid_cable` before the first deploy.
