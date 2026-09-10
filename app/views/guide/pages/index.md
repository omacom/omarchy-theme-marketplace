# Guide

How to build an Omarchy theme, list it on the marketplace, and use it once it's installed — start to finish.

## Make a theme

A theme is a public GitHub repository with a `colors.toml` palette, a `backgrounds/` folder of wallpapers, and a `preview.png` screenshot at the root. Omarchy generates every application's colours from the palette when the theme is applied.

The [Omarchy manual](https://omarchy.org/manual/making-your-own-theme/) has the full guide to building one. Before you submit it:

- Name the repository `omarchy-<name>-theme`. The part between the prefix and suffix becomes the theme's install name — lowercase, only letters, digits, `.`, `_`, `+` and `-`.
- Set `mode = "light"` or `mode = "dark"` in `colors.toml`.
- Save a 16:9 screenshot of the theme on a real desktop as `preview.png`. Omarchy's own theme switcher shows this exact file, and so does the marketplace.
- Keep wallpapers a few MB each — `magick in.png -strip -resize '3840>' -quality 82 out.webp`.

Omarchy drops anything that could run code when a theme is installed from a repo: `.lua` files, terminal configs (`alacritty.toml`, `foot.ini`, `ghostty.conf`, `kitty.conf`), `vscode.json`, and symlinks. Don't build the theme around those — they're regenerated from `colors.toml`.

## Submit a theme

Fill out the [**Submit a theme**](https://github.com/omacom/omarchy-theme-registry/issues/new?template=submit-theme.yml) form with your repository URL. That's the whole submission.

1. A bot validates your repository the same way Omarchy installs it, and comments the report on your issue — usually within minutes.
2. **Passed:** a pull request is opened and merged for you. No extra step.
3. **Needs changes:** fix your repository, then comment `/recheck` on your issue. No need to start over.

Once listed, the marketplace follows your repository's default branch — push changes and the listing updates on the next refresh (every six hours). Updates never need a new submission.

## What gets checked

**Blocks a listing** — repository missing, private, or over 400 MB; theme files not at the repository root; symlinks; no palette, or one missing `accent`, `background`, `foreground`, `red`, `yellow`, `green`, `cyan`, `blue` or `magenta`; no `preview.png` at the root, or narrower than 1000 px; an image over 50 MB or 40 megapixels; an install name that's invalid, built-in, or already taken (first claim keeps it).

**Shown as notes, never blocks** — files Omarchy drops on install; `mode` missing or declared inconsistently; wallpapers missing, oversized, in subfolders, or with unusual filenames; a preview that isn't 16:9; no README, LICENSE, or `omarchy-theme` GitHub topic; scripts or binaries in the repository.

A repository that goes missing keeps its listing for three checks (about 18 hours), then drops out until it returns.

## Install, update, and remove

Every theme page has an install command:

```sh
omarchy theme install https://github.com/<owner>/omarchy-<name>-theme
```

Or use the menu: **Super + Space → Install → Style → Theme**.

- **Switch** — Super + Ctrl + Shift + Space opens the theme switcher.
- **Update** — `omarchy theme update` pulls the latest commit of every installed theme, or **Update → Extra Themes** in the menu.
- **Remove** — `omarchy theme remove <name>`, or **Remove → Theme** in the menu. Switch to another theme first if the one you're removing is active.

Themes installed from a repository can only contribute colours, wallpapers and previews — never code.
