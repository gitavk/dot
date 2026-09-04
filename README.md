# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each folder
under `stow/` is a "package" that mirrors its target path relative to `$HOME`.

## Structure

```
stow/
  bspwm/.config/bspwm/...
  sxhkd/.config/sxhkd/...
  alacritty/.config/alacritty/...
  polybar/.config/polybar/...
  rofi/.config/rofi/...
  zellij/.config/zellij/...
  bash/.bashrc
  git/.gitconfig
  x11/.Xresources
  x11/.xinitrc
```

## Setup on a new machine

```bash
emerge app-admin/stow          # or apt install stow, etc.
git clone git@github.com:gitavk/dot.git ~/dotfiles
cd ~/dotfiles/stow
stow -t ~ bspwm sxhkd alacritty polybar rofi zellij bash git x11
```

`-t ~` tells stow to link into `$HOME` (needed because `stow/` itself
lives one level deeper than a plain dotfiles-in-repo-root layout).

## Adding a new config

1. Put the file where it should live on disk, under the right package,
   e.g. `stow/foo/.config/foo/config.toml`.
2. Run `stow -t ~ foo` from `~/dotfiles/stow`.
3. `git add -A && git commit && git push`.

## Removing a package (undo the symlinks)

```bash
cd ~/dotfiles/stow
stow -D -t ~ foo
```

## Notes

- `config/claude/`, `config/etc/`, `skills/` at the repo root are **not**
  stow packages — they're not meant to be symlinked into `$HOME` directly.
- `~/.config/nvim` is a separate git repo (`nvim.lazy`), cloned directly
  into place — not managed by stow.
- If stow complains about an existing file conflicting with a symlink it
  wants to create, remove/back up that file first, then re-run stow.
