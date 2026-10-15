# dotfiles

Personal dotfiles and macOS setup notes. The Git worktree is the home
directory (`/Users/haruo`), so tracked files live at the same paths used by
macOS and Home Manager.

## Repository map

- `.profile` keeps the remaining login-shell bootstrap outside Home Manager.
- `.vimrc` and `.tmux.conf` keep the user-managed Vim and tmux settings.
- `.agents/.skill-lock.json` pins shared agent skill installations.
- `.claude/settings.json` keeps the shareable Claude Code settings.
- `.config/git/ignore` keeps the global Git ignore rules. Git identity and
  credential-helper settings are generated from Home Manager.
- `.config/nix/nix.conf` keeps the user-level Nix CLI settings.
- `.config/nix-darwin/flake.nix` manages system packages and macOS defaults.
- `.config/nix-darwin/home.nix` manages user packages, zsh, Vim, Home Manager
  files, and user launchd agents.
- `.config/nix-darwin/flake.lock` pins the Nix inputs.
- `.config/snapzy/config.toml` and `.config/zed/settings.json` keep shareable
  application preferences.
- `.gitignore` uses an allowlist so unrelated files in the home directory are
  never shown or staged accidentally.

Authentication, history, caches, generated files, and machine-local settings
are intentionally excluded. Examples include `.codex/auth.json`,
`.codex/config.toml` (currently contains an API key), `.config/gh/hosts.yml`,
`.config/x-bookmarks/cookies.json`, `.claude.json*`, `.zsh_history`,
`.viminfo`, and `.zcompdump*`.

## Nix managed macOS setup

The current macOS environment is managed with nix-darwin and Home Manager.
`flake.nix` defines one configuration per Mac under its `LocalHostName`, so
`darwin-rebuild` picks the right one automatically.

Apply the configuration with:

```sh
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
```

`nix-up` (an alias for `.config/nix-darwin/nix-up.sh`) also updates the flake
inputs, applies them, and commits and pushes `flake.lock`. Run it on the Mac
you mean to update: it acts on the machine it runs on.

Build without applying:

```sh
nix build ~/.config/nix-darwin#darwinConfigurations.$(scutil --get LocalHostName).system --no-link
```

Running the system activation needs a terminal with Full Disk Access
(System Settings → Privacy & Security). Without it, writing the
`com.apple.universalaccess` defaults fails with "Could not write domain" and
activation stops halfway.

### Hosts and the main Mac

| Host | `isMainMac` | Role |
|---|---|---|
| `HaruonoMac-Studio` | `true` | Main machine since 2026-10-16 |
| `Haruos-MacBook-Pro` | `false` | Secondary machine |

Both hosts share every package and setting. The only difference is
`isMainMac`, which `home.nix` uses to enable the launchd agents that must not
run on two Macs at once: the agents that write the Obsidian vault (synced to
every device by Obsidian Sync), ComfyUI, and the NAS database tunnel. Exactly
one host should set it to `true`.

To move the main role to another Mac:

1. Prepare what the agents need on the new Mac (projects, ComfyUI, SSH keys
   and the `kakari-auto` alias, cookies, the vault synced by Obsidian Sync).
2. On the old Mac, stop the agents right away with
   `launchctl bootout gui/$(id -u)/com.haruo.<name>`.
3. Flip `isMainMac` in `flake.nix`, commit, and push.
4. Run `git pull` and apply on **both** Macs. `bootout` alone is temporary:
   the plists stay and load again at the next login until Home Manager
   removes them.

`devlog` builds its log from the local Claude Code and Codex transcripts, so
after a move the day's file only covers work done on the new Mac.

### Setting up a new Mac

The order below avoids the problems hit while setting up the Mac Studio.

1. Install the Command Line Tools (`xcode-select --install`). Until they are
   installed, `git` and `python3` are only stubs.
2. Make the home directory the worktree without overwriting anything:
   `git init -b master`, add `origin`, `git fetch`, then
   `git checkout -b master --track origin/master`. `checkout` refuses to
   overwrite existing files, so nothing is lost.
3. Install Nix with the official multi-user installer
   (`https://nixos.org/nix/install --daemon`). nix-darwin manages `nix.conf`
   itself, so do not use an installer that takes over Nix management.
4. Add the new `LocalHostName` to `flake.nix` with `isMainMac = false`, and
   check it with `nix build` before applying anything.
5. Apply for the first time with the built system's own `darwin-rebuild`:
   `sudo <store path>/sw/bin/darwin-rebuild switch --flake ~/.config/nix-darwin`.
   nix-darwin refuses to overwrite `/etc/bashrc` and `/etc/zshrc`. They
   contain only the macOS defaults plus the Nix installer's lines, so rename
   them with a `.before-nix-darwin` suffix and run it again.
6. Sign in to GitHub with `gh auth login`. Git uses `gh` as its credential
   helper, and system-kakari is cloned over HTTPS, so the new Mac needs no
   GitHub SSH key.
7. Sign in to Claude Code with `claude /login` (`claude` comes from
   `pkgs.claude-code`). CodexBar reads Claude plan usage from the Keychain
   item this creates; without it CodexBar shows "Claude OAuth credentials not
   found".

On macOS 15 and later, apps need the Local Network permission to reach LAN
hosts. A terminal without it gets "No route to host" over SSH even though
`ping` works. launchd agents are not affected.

### Claude extensions fixed on every activation

Claude Desktop extensions overwrite their manifests when they update, so
`home.nix` rewrites two of them on each activation:

- `pinMacosMcpUv`: keeps the macOS MCP extension on a pinned `uv`, so the
  accessibility permission survives `nix-up`.
- `pinAwsMcpDeps`: runs the AWS API MCP extension with `mcp<2` and
  `fastmcp<3`. Version 1.3.3 locks `mcp` 2.x but still imports the 1.x
  `McpError`, so it fails at startup. The rewrite applies only while the
  installed code still imports `McpError`.

Restart Claude after an activation that prints one of these fixes.

## zsh

`~/.zshrc` is generated by Home Manager and is intentionally not tracked.
Edit zsh behavior in `.config/nix-darwin/home.nix`, then rebuild.

## Vim and tmux

Vim itself is installed as `pkgs.vim`, while `.vimrc` is tracked directly and
is not generated by Home Manager. The restored dein plugin section is guarded,
so Vim still starts when `~/.vim/dein` is not installed.

`.tmux.conf` is tracked for future use. tmux, fish, and
`reattach-to-user-namespace` are not currently installed by this configuration.

## GitHub and Zed

GitHub authentication for Git is handled by GitHub CLI over HTTPS.
`.config/nix-darwin/home.nix` installs `gh` and configures Git to use
`gh auth git-credential` for `github.com` and `gist.github.com`.

Zed uses the local Git configuration for Git operations. `core.editor` is set
to `zeditor --wait` because the Nix package exposes the Zed CLI as `zeditor`.

## Updating dotfiles

Because the home directory is the worktree, no synchronization script is
needed. Edit the real file, then review, commit, and push from `~/`:

```sh
cd ~
git diff
git status --short
git add <updated-files>
git commit -m "<change summary>"
git push origin master
```

New dotfile paths must first be explicitly allowlisted in `.gitignore`. Do not
use broad `git add -A` or `git add -f` commands, and never commit secrets.
