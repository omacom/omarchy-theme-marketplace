How to build an Omarchy theme, list it on the marketplace, and use it once it's installed — start to finish.

## Make a theme

A theme is a public GitHub repository with a `colors.toml` palette, a `backgrounds/` folder of wallpapers, and a `preview.png` screenshot at the root. Omarchy generates every application's colours from the palette when the theme is applied.

The [Omarchy manual](https://omarchy.org/manual/making-your-own-theme/) has the full guide to building one. Before you submit it:

- Name the repository `omarchy-<name>-theme`. The part between the prefix and suffix becomes the theme's install name — lowercase, only letters, digits, `.`, `_`, `+` and `-`. If another theme already has that name, yours gets your GitHub username added (`gruvbox-yourname`), and the validation report says so.
- Set `mode = "light"` or `mode = "dark"` in `colors.toml`.
- Save a 16:9 screenshot of the theme on a real desktop as `preview.png`. Omarchy's own theme switcher shows this exact file, and so does the marketplace.
- Keep wallpapers a few MB each — `magick in.png -strip -resize '3840>' -quality 82 out.webp`.

Omarchy drops anything that could run code when a theme is installed from a repo: `.lua` files, terminal configs (`alacritty.toml`, `foot.ini`, `ghostty.conf`, `kitty.conf`), `vscode.json`, and symlinks. Don't build the theme around those — they're regenerated from `colors.toml`.

## Submit a theme

Fill out the [**Submit a theme**](https://github.com/omacom/omarchy-theme-registry/issues/new?template=submit-theme.yml) form with your repository URL. That's the whole submission.

1. A bot validates your repository the same way Omarchy installs it, and comments the report on your issue — usually within minutes.
2. **Passed:** a pull request is opened for a maintainer to merge. Once it is merged, your theme appears with the next catalog build, which runs every six hours.
3. **Needs changes:** fix your repository, then comment `/recheck` on your issue. No need to start over.

Once listed, the marketplace follows your repository's default branch — push changes and the listing updates on the next refresh (every six hours). Updates never need a new submission.

## What gets checked

**Blocks a listing** — repository missing, private, or over 400 MB; theme files not at the repository root; symlinks; no palette, or one missing `accent`, `background`, `foreground`, `red`, `yellow`, `green`, `cyan`, `blue` or `magenta`; no `preview.png` at the root, or narrower than 1000 px; an image over 50 MB or 40 megapixels; a repository name that gives an install name Omarchy refuses.

**Shown as notes, never blocks** — files Omarchy drops on install; `mode` missing or declared inconsistently; wallpapers missing, oversized, in subfolders, or with unusual filenames; a preview that isn't 16:9; no README, LICENSE, or `omarchy-theme` GitHub topic; scripts or binaries in the repository.

A listed theme is checked again every six hours. If its repository goes missing, turns private, or stops passing these checks, it drops off the marketplace at the next check, and you get a GitHub notification listing what to fix. It comes back automatically once it passes again. There's no need to resubmit.

## Theme health

Some themes have a small clipboard and letter beside their GitHub stars. It opens an **advisory report card**: theme integrity, text contrast, state distinction, shell surfaces, and sampled wallpaper resilience. It measures functional properties, not taste, security, or overall accessibility. It never changes a listing, installation, gallery order, or featured status.

- **A–F:** the analyzer's grade for the theme commit shown in the report, generated using a pinned, supported Omarchy revision without personal overrides.
- **An asterisk, such as B\*:** provisional. Some checks were not measured; those checks are not treated as passes.
- **Out of date:** the theme commit changed. The old letter is not shown as a current rating.
- **Not checked:** no supported report is available. It does not mean the theme failed.

Open an area to read its findings, targets and suggested improvements. The report identifies its theme commit, check time, analyzer, experimental ruleset, profile and Omarchy revision. Translucent surfaces use reference backgrounds and wallpapers are sampled, not exhaustively tested; these are not captures of your desktop or an accessibility certification. Measurement assumptions and JSON are available on the theme page.

Measurements are optional and refresh with the catalog when the analyzer is available. A missing tool, unsupported runtime or audit error leaves the theme available without a current grade. If the measurements suggest a change, the theme page links to the artist's repository; the website never edits or runs a theme.

## Install, update, and remove

Every theme page has an install command:

```sh
omarchy theme install <name>
```

Or browse every listed theme from Omarchy: `omarchy theme browse`, or **Super + Space → Install → Style → Theme**.

Installing by name checks out the commit the marketplace validated, and only the files Omarchy reads from a theme.

- **Switch** — Super + Ctrl + Shift + Space opens the theme switcher.
- **Update** — `omarchy theme update` moves each installed theme to its newest validated commit, or **Update → Extra Themes** in the menu.
- **Remove** — `omarchy theme remove <name>`, or **Remove → Theme** in the menu. Switch to another theme first if the one you're removing is active.

Themes installed from a repository can only contribute colours, wallpapers and previews — never code.
