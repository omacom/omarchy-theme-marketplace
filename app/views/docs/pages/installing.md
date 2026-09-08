# Installing themes

Every theme page shows an install command. Paste it in a terminal:

```sh
omarchy theme install https://github.com/<owner>/omarchy-<name>-theme
```

Omarchy clones the repository into `~/.config/omarchy/themes/<name>` and applies the theme right away. You can also use the menu: **Super + Space → Install → Style → Theme** and paste the repository URL.

## Switching

**Super + Ctrl + Shift + Space** opens the theme switcher with every built-in and installed theme. Wallpapers cycle with **Super + Ctrl + Space**.

## Updating

```sh
omarchy theme update
```

pulls the latest commit of every installed theme. The menu equivalent is **Update → Extra Themes**.

## Removing

```sh
omarchy theme remove <name>
```

or **Remove → Theme** in the menu. Switch to another theme first if the one you are removing is active.

## Safety

Themes installed from a repository can only contribute colours, wallpapers and previews. Omarchy drops `.lua` files, terminal configs, `vscode.json` and symlinks on install, so a theme cannot run code on your machine.
