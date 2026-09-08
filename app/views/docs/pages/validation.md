# What gets checked

Every listed theme passes an automated validation that mirrors what `omarchy theme install` enforces, plus what makes a good listing. It runs when a theme is submitted and again every six hours, against the default branch of the repository — the same commit `omarchy theme install` would clone. The commit that passed is shown on the theme page as **Validated**.

## Blocking

A theme with any of these is not listed until it is fixed:

- The repository is missing or private.
- The install name (repository name minus `omarchy-` and `-theme`) is invalid, matches one of the 22 built-in themes, or is already claimed by another listed theme. First claim keeps the name.
- Theme files are not at the repository root.
- The repository contains symlinks.
- There is no palette — no `colors.toml`, and no legacy `alacritty.toml` to derive one from — or the palette is missing `accent`, `background`, `foreground`, `red`, `yellow`, `green`, `cyan`, `blue` or `magenta`, or one of those is not a colour.
- There is no `preview.png` (or `.jpg`/`.webp`) at the root, or it is narrower than 1000 px.
- An image is over 50 MB or 40 megapixels, or the repository is over 400 MB.

## Notes

These never block a listing; they appear under **Good to know** on the theme page so the author can improve the theme:

- Files Omarchy drops when installing from a repository (`.lua` files, terminal configs, `vscode.json`).
- `mode` not declared in `colors.toml`, or declared inconsistently.
- Optional palette keys missing or invalid.
- Wallpapers missing, very large, in subfolders (ignored by Omarchy), with spaces in their names, or videos.
- The preview is not 16:9.
- No README, no LICENSE, no `omarchy-theme` GitHub topic, or a repository name that does not follow `omarchy-<name>-theme`.
- Scripts, launchers or binaries in the repository. Omarchy never runs them, but reviewers look.

## Liveness

A repository that disappears keeps its listing for three consecutive checks (about 18 hours) and is then removed until it returns. Renamed repositories keep working through GitHub's redirect, but the install name changes with the repository name.
