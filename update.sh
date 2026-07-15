#!/bin/sh

set -eu

# Refresh tracked files from the current machine.
#
# Source files managed by Home Manager (e.g. ~/.zshrc) are symlinks into the
# read-only Nix store, and some tracked files (.vimrc, .tmux.conf, config.fish)
# may not exist as real files at all. So we skip missing sources with a warning
# instead of aborting, and make each destination writable before overwriting
# (a prior copy can leave it read-only, inheriting the Nix store's 0444).

# sync <source> <destination>
sync() {
  src="$1"
  dst="$2"

  if [ ! -e "$src" ]; then
    echo "skip: $src (not found)" >&2
    return 0
  fi

  dst_dir=$(dirname "$dst")
  mkdir -p "$dst_dir"

  # If the destination already exists, ensure it is writable before overwrite.
  [ -e "$dst" ] && chmod u+w "$dst"

  # -L follows symlinks so we copy the resolved content (Home Manager targets),
  # not the link itself.
  cp -L "$src" "$dst"

  # Normalize permissions so the next run can overwrite without chmod games.
  chmod u+w "$dst"

  echo "copied: $src -> $dst"
}

sync ~/.vimrc ./.vimrc
sync ~/.config/fish/config.fish ./config.fish
sync ~/.tmux.conf ./.tmux.conf

sync ~/.config/nix-darwin/flake.nix nix-darwin/flake.nix
sync ~/.config/nix-darwin/home.nix nix-darwin/home.nix
sync ~/.config/nix-darwin/flake.lock nix-darwin/flake.lock
sync ~/.zshrc zsh/.zshrc.generated
