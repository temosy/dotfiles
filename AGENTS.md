# Agent instructions

The home directory (`/Users/haruo`) is both the live dotfiles location and the
Git worktree for `https://github.com/temosy/dotfiles`.

## Required workflow

When an AI agent changes a tracked dotfile, including files under
`~/.config/nix-darwin/`, it must finish the same task by:

1. Running Git commands from `/Users/haruo`; no synchronization or copy step
   is needed.
2. Reviewing `git diff` and `git status --short`.
3. Excluding unrelated changes and secrets.
4. Staging only explicit paths, then committing the relevant files.
5. Pushing the commit to `origin master`
   (`https://github.com/temosy/dotfiles`).

The root `.gitignore` is an allowlist. When adding a new dotfile path, update
the allowlist deliberately. Never use a broad `git add -A` or `git add -f`
against the home directory.

Do not report the dotfiles update as complete while its reviewed repository
changes remain uncommitted or unpushed.
