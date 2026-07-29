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

Before tracking a file, inspect it for API keys, tokens, credentials, cookies,
history, caches, and machine-generated state. Track the declarative source
instead of Home Manager-generated symlinks such as `.zshrc`, `.zprofile`,
`.zshenv`, and `.config/git/config`.

Do not report the dotfiles update as complete while its reviewed repository
changes remain uncommitted or unpushed.

## Git and pull requests

These rules apply to every repository, not only to dotfiles.

Delete the head branch once a pull request is merged. Confirm first that
`git diff --stat origin/main origin/<branch>` is empty. Do not rely on
`git branch --merged`: a squash merge rewrites the SHA, so a merged branch
still looks unmerged. Ask before running the deletion.

Enable `delete_branch_on_merge` on new repositories:
`gh api -X PATCH repos/<owner>/<repo> -F delete_branch_on_merge=true`.
As of 2026-07-29 every existing temosy repository already has it.

Do not stack pull requests. Wait for the earlier one to merge and target `main`
directly. If a pull request was stacked anyway, verify after the earlier merge
that the base switched to `main` (`gh pr view <n> --json baseRefName`). GitHub
retargets a stacked pull request only when the base branch is deleted. On
2026-07-29 a stacked pull request was reported as merged while it had in fact
landed on the surviving base branch and never reached `main`.

When told that a pull request was merged, verify it. Check `git log origin/main`
and, for a new file, `git cat-file -e origin/main:<path>`.

The reasoning and the incident log live in
`~/Documents/Startup/開発運用ルール_GitとPRの扱い.md`.
