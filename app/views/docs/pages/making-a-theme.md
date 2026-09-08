# Making a theme

A theme is a git repository. At its simplest it contains a `colors.toml` palette, a `backgrounds/` folder of wallpapers, and a `preview.png` screenshot. Omarchy generates every application's colours from the palette when the theme is applied.

The Omarchy manual has the full guide: [Making your own theme](https://omarchy.org/manual/making-your-own-theme/). The short version:

1. Copy a built-in theme from `/usr/share/omarchy/themes` into `~/.config/omarchy/themes/<name>` and edit `colors.toml`. Set `mode = "light"` or `mode = "dark"`.
2. Put your wallpapers directly inside `backgrounds/` (JPEG, PNG, WebP; keep them a few MB each — `magick in.png -strip -resize '3840>' -quality 82 out.webp`).
3. Take a 16:9 screenshot of the theme on a real desktop with a terminal and an editor open and save it as `preview.png` at the repository root. Omarchy shows this exact file in its theme switcher, and so does the marketplace.
4. Push to a public GitHub repository named `omarchy-<name>-theme`. The name between the prefix and suffix becomes the theme's install name, so keep it lowercase with only letters, digits, `.`, `_`, `+` and `-`.

## What an installed theme can contain

When a theme is installed from a repository, Omarchy keeps everything that is colour and drops the handful of files that would run code on the user's machine: any `.lua` file, the terminal configs (`alacritty.toml`, `foot.ini`, `ghostty.conf`, `kitty.conf`), `vscode.json`, and symlinks. Do not build the theme around those; they are regenerated from `colors.toml`.

## Listing it on the marketplace

Open a pull request against [omacom/omarchy-theme-registry](https://github.com/omacom/omarchy-theme-registry) that adds `themes/<name>.json`:

```json
{
  "slug": "<name>",
  "repo": "https://github.com/you/omarchy-<name>-theme",
  "name": "Display Name",
  "submitted_by": "your-github-login",
  "added_at": "2026-09-08"
}
```

The validator runs on the pull request and comments its report. A submission form on this site is on the way and will do this for you.
