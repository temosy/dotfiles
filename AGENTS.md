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

## Check the available tools first

MCP tools arrive as a bare list of more than two hundred names with no
descriptions; they are deferred, and their schemas load only on demand through
`ToolSearch`. Anything not deliberately looked for stays buried, so confirm with
`ToolSearch` before concluding that a capability is missing.

- Thunderbird mail, folders, calendar, contacts — `mcp__thunderbird-mail__*`
- Browser work needing the signed-in Chrome — `mcp__claude-in-chrome__*`
- Throwaway browser verification — the Browser pane or `mcp__playwright__*`
- macOS native applications — `mcp__computer-use__*`, `mcp__MacOS-MCP__*`
- Recalling earlier conversations — `mcp__episodic-memory__*`

Gmail, Google Calendar, Google Drive, Vercel, and Figma are connected as well,
but their server names are UUIDs and cannot be recognized by sight. Find them by
passing keywords (`gmail`, `calendar`, `drive`) to `ToolSearch`.

Look for an application's own MCP server before touching its data directly. On
2026-08-15 an agent tried to clean up Thunderbird mail with `rm` and by driving
the GUI; both were correctly blocked, and the MCP `deleteFolder` tool did the job.

## Git and pull requests

These rules apply to every repository, not only to dotfiles.

Delete the head branch once a pull request is merged. **Verify, then delete
without asking** — asking every time is noise (2026-08-13). The check is that
the branch's tip is exactly the head commit of a *merged* pull request, which
also proves no local commit was left behind:

```bash
b=<branch>
[ "$(git rev-parse "$b")" = "$(gh pr list --head "$b" --state merged --json headRefOid -q '.[0].headRefOid')" ] \
  && git branch -D "$b"
```

This is the authoritative check. A squash merge rewrites the SHA, so
`git branch --merged` and `git log main..<branch>` both call a merged branch
unmerged; `gh` knows the truth. Comparing the local tip guards the one real
risk — a commit made locally after the pull request was pushed.

Do not use a diff-based check as the primary test. `git diff --numstat` reads
wrong in three ways, all hit in practice:

- Naming the branch as `origin/<branch>` fails with a fatal error, because
  `delete_branch_on_merge` already removed the remote branch. The error goes to
  stderr and stdout stays empty, which looks exactly like a clean diff
  (2026-08-08). Pass the local branch name instead.
- Once `main` moves ahead, a merged branch no longer has an empty diff: lines a
  later pull request added show up as deletions (2026-08-08). That branch is
  still safe to delete.
- **Scoping the diff to the files the branch touched does not save it.** If a
  later pull request rewrote those same files, the branch's already-merged
  lines come back as insertions and a merged branch looks unmerged (2026-08-13:
  a branch fully contained in `main` reported 62 insertions, because the next
  pull request replaced that function).

Fall back to the diff check only when there is no pull request to consult, and
read its output with the three failure modes above in mind.

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
