# Agent instructions

This repository is the persistent source for haruo's dotfiles.

## Required workflow

When an AI agent changes dotfiles on the current machine, including files under
`~/.config/nix-darwin/`, it must finish the same task by:

1. Synchronizing the relevant files into `/Users/haruo/projects/dotfiles`
   (`./update.sh` is available for a full refresh).
2. Reviewing `git diff` and `git status --short`.
3. Excluding unrelated changes and secrets.
4. Committing the relevant files.
5. Pushing the commit to `origin master`
   (`https://github.com/temosy/dotfiles`).

Do not report the dotfiles update as complete while its reviewed repository
changes remain uncommitted or unpushed.
