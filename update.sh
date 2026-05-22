#!/bin/sh

set -eu

cp ~/.vimrc ./
cp ~/.config/fish/config.fish ./
cp ~/.tmux.conf ./

mkdir -p nix-darwin zsh
cp ~/.config/nix-darwin/flake.nix nix-darwin/
cp ~/.config/nix-darwin/home.nix nix-darwin/
cp ~/.config/nix-darwin/flake.lock nix-darwin/
cp ~/.zshrc zsh/.zshrc.generated
