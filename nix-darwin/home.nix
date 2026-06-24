{ pkgs, lib, ... }:

let
  mattPocockSkills = pkgs.fetchFromGitHub {
    owner = "mattpocock";
    repo = "skills";
    rev = "b8be62ffacb0118fa3eaa29a0923c87c8c11985c";
    hash = "sha256-Qwuu27f95xgAJ4hdv/4TNahHhprCMIxl1H9f9ymEsno=";
  };

  codexbar = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "codexbar";
    version = "0.27.0";

    src = pkgs.fetchurl {
      url = "https://github.com/steipete/CodexBar/releases/download/v${version}/CodexBar-macos-universal-${version}.zip";
      hash = "sha256-tDnsrw7SNa+oCRYbGyzkCZpuWTxmL1677VfamZuXz5E=";
    };

    cliSrc = pkgs.fetchurl {
      url = "https://github.com/steipete/CodexBar/releases/download/v${version}/CodexBarCLI-v${version}-macos-arm64.tar.gz";
      hash = "sha256-v3k5ZL3Mxvnas+suQOEa47JWbfAx6FiwZf1ujqRBbcI=";
    };

    nativeBuildInputs = [ pkgs.unzip ];

    unpackPhase = ''
      runHook preUnpack
      unzip -q "$src"
      mkdir cli
      tar -xzf "$cliSrc" -C cli
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications" "$out/bin" "$out/share/codexbar"
      cp -R CodexBar.app "$out/Applications/"
      install -m 0755 cli/CodexBarCLI "$out/bin/CodexBarCLI"
      ln -s "$out/bin/CodexBarCLI" "$out/bin/codexbar"
      install -m 0644 cli/VERSION "$out/share/codexbar/VERSION"
      runHook postInstall
    '';

    meta = {
      description = "macOS menu bar app and CLI for AI coding provider usage limits";
      homepage = "https://github.com/steipete/CodexBar";
      license = lib.licenses.mit;
      platforms = [ "aarch64-darwin" ];
    };
  };
in

{
  home.stateVersion = "24.11";

  home.sessionPath = [
    "/Users/haruo/.npm-global/bin"
  ];

  home.sessionVariables = {
    LC_ALL = "en_US.UTF-8";
    LANG = "ja_JP.UTF-8";
    EDITOR = "vim";
  };

  home.activation.createScreenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/screenshots"
  '';

  home.file.".agents/skills/grill-with-docs" = {
    source = "${mattPocockSkills}/skills/engineering/grill-with-docs";
    force = true;
  };

  home.file.".claude/skills/grill-with-docs" = {
    source = "${mattPocockSkills}/skills/engineering/grill-with-docs";
    force = true;
  };

  home.file.".codex/skills/grill-with-docs" = {
    source = "${mattPocockSkills}/skills/engineering/grill-with-docs";
    force = true;
  };

  home.file."Documents/Startup/.agents/skills/grill-with-docs" = {
    source = "${mattPocockSkills}/skills/engineering/grill-with-docs";
    force = true;
  };

  home.file."Documents/Startup/.claude/skills/grill-with-docs" = {
    source = "${mattPocockSkills}/skills/engineering/grill-with-docs";
    force = true;
  };

  home.activation.configureTerminalFont = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    terminal_plist="$HOME/Library/Preferences/com.apple.Terminal.plist"
    terminal_profile="Ocean"
    terminal_font_data="YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9iamVjdHMSAAGGoF8QD05TS2V5ZWRBcmNoaXZlctEICVRyb290gAGkCwwVFlUkbnVsbNQNDg8QERITFFZOU1NpemVYTlNmRmxhZ3NWTlNOYW1lViRjbGFzcyNAKAAAAAAAABAQgAKAA18QF1NvdXJjZUhhbkNvZGVKUC1SZWd1bGFy0hcYGRpaJGNsYXNzbmFtZVgkY2xhc3Nlc1ZOU0ZvbnSiGRtYTlNPYmplY3QIERokKTI3SUxRU1heZ253foWOkJKUrrO+x87RAAAAAAAAAQEAAAAAAAAAHAAAAAAAAAAAAAAAAAAAANo="

    [ -f "$terminal_plist" ] || exit 0

    tmp="$(mktemp)"
    /usr/bin/defaults export com.apple.Terminal "$tmp"

    /usr/bin/plutil -replace "Default Window Settings" -string "$terminal_profile" "$tmp"
    /usr/bin/plutil -replace "Startup Window Settings" -string "$terminal_profile" "$tmp"

    for profile_key in "Default Window Settings" "Startup Window Settings"; do
      profile="$(/usr/libexec/PlistBuddy -c "Print :\"$profile_key\"" "$tmp" 2>/dev/null || true)"
      [ -n "$profile" ] || continue
      /usr/bin/plutil -replace "Window Settings.$profile.Font" -data "$terminal_font_data" "$tmp"
    done

    /usr/bin/defaults import com.apple.Terminal "$tmp"
    rm -f "$tmp"
  '';

  home.packages = [
    pkgs.claude-code
    pkgs.claude-monitor
    pkgs.codex
    codexbar
    pkgs.gh
    pkgs.nodejs
    pkgs.obsidian
    pkgs.ghq
    pkgs.peco
    pkgs.python3
    pkgs.thunderbird
    pkgs.tree
    pkgs.uv
    pkgs.vscode
    pkgs.yt-dlp
  ];

  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
    };
    history = {
      size = 1000000;
      save = 1000000;
      append = true;
    };
    autosuggestion = {
      enable = true;
      strategy = [ "history" "completion" ];
      highlight = "fg=8";
    };
    syntaxHighlighting.enable = true;
    shellAliases = {
      python = "python3";
      subl = "/Applications/Sublime\\ Text.app/Contents/SharedSupport/bin/subl";
      gitlog = "git log --oneline --graph";
      youtube-dl = "yt-dlp";
      ya = ''yt-dlp -x --embed-thumbnail --audio-format mp3 --audio-quality 0 -o "$HOME/Music/%(title)s.%(ext)s"'';
      yaf = ''yt-dlp -x --audio-format flac --audio-quality 0 -o "$HOME/Music/%(title)s.%(ext)s"'';
    };
    initContent = ''
      typeset -U path

      for dir in "$HOME/bin" /usr/local/sbin "$HOME/Library/Android/sdk/platform-tools"; do
        [[ -d "$dir" ]] && path=("$dir" $path)
      done

      if [[ -d /Library/Java/JavaVirtualMachines/jdk-13.0.2.jdk/Contents/Home ]]; then
        export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-13.0.2.jdk/Contents/Home"
      fi

      USER_BASE_PATH="$(python3 -m site --user-base 2>/dev/null)"
      if [[ -n "$USER_BASE_PATH" ]]; then
        export USER_BASE_PATH
        path=("$USER_BASE_PATH" "$USER_BASE_PATH/bin" $path)
      fi

      if [[ -d "$HOME/.anyenv/bin" ]]; then
        path=("$HOME/.anyenv/bin" $path)
        if command -v anyenv >/dev/null 2>&1; then
          eval "$(anyenv init - zsh)"
        fi
      fi

      if [[ -n "$RBENV_ROOT" && -d "$HOME/$RBENV_ROOT/shims" ]]; then
        path=("$HOME/$RBENV_ROOT/shims" $path)
      fi

      if [[ -n "$GOPATH" ]]; then
        [[ -d "$GOPATH" ]] && path=("$GOPATH" $path)
        [[ -d "$GOPATH/bin" ]] && path=("$GOPATH/bin" $path)
      fi

      export PATH

      nico-video-load-credentials() {
        if [[ -n "$NICO_VIDEO_USER" && -n "$NICO_VIDEO_PASS" ]]; then
          return 0
        fi

        if ! command -v op >/dev/null 2>&1; then
          print -u2 "1Password CLI (op) is not available."
          return 1
        fi

        NICO_VIDEO_USER="$(op read "op://Private/niconico/username")" || return 1
        NICO_VIDEO_PASS="$(op read "op://Private/niconico/password")" || return 1
        export NICO_VIDEO_USER NICO_VIDEO_PASS
      }

      na() {
        nico-video-load-credentials || return
        yt-dlp -u "$NICO_VIDEO_USER" -p "$NICO_VIDEO_PASS" -x --embed-thumbnail --audio-format mp3 --audio-quality 0 -o "$HOME/Music/%(title)s.%(ext)s" "$@"
      }

      naf() {
        nico-video-load-credentials || return
        yt-dlp -u "$NICO_VIDEO_USER" -p "$NICO_VIDEO_PASS" -x --audio-format flac --audio-quality 0 -o "$HOME/Music/%(title)s.%(ext)s" "$@"
      }

      if command -v peco >/dev/null 2>&1; then
        peco-select-history() {
          local selected
          selected=$(fc -rl 1 | sed 's/^ *[0-9]* *//' | peco --query "$LBUFFER")
          [[ -z "$selected" ]] && return
          BUFFER="$selected"
          CURSOR=''${#BUFFER}
        }
        zle -N peco-select-history
        bindkey '^R' peco-select-history

        peco-select-ghq-repository() {
          command -v ghq >/dev/null 2>&1 || return

          local selected
          selected=$(ghq list -p | peco --query "$LBUFFER")
          [[ -z "$selected" ]] && return
          cd "$selected" || return
          zle reset-prompt
        }
        zle -N peco-select-ghq-repository
        bindkey '^]' peco-select-ghq-repository
      fi
    '';
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Haruo Shimote";
        email = "587726+temosy@users.noreply.github.com";
      };
      core.editor = "vim";
      init.defaultBranch = "main";
      credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
      credential."https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
    };
  };

  launchd.agents.x-bookmarks = {
    enable = true;
    config = {
      Label = "com.haruo.x-bookmarks";
      ProgramArguments = [
        "/bin/sh" "-lc"
        "cd /Users/haruo/projects/x-bookmarks && /etc/profiles/per-user/haruo/bin/npm run run"
      ];
      StartCalendarInterval = [ { Hour = 7; Minute = 30; } ];
      StandardOutPath = "/Users/haruo/Library/Logs/x-bookmarks.log";
      StandardErrorPath = "/Users/haruo/Library/Logs/x-bookmarks.err.log";
      RunAtLoad = false;
    };
  };

  launchd.agents.normalize-screenshot-names = {
    enable = true;
    config = {
      Label = "com.haruo.normalize-screenshot-names";
      ProgramArguments = [
        "/bin/zsh" "-lc"
        ''
          dir="$HOME/screenshots"
          [ -d "$dir" ] || exit 0

          setopt null_glob
          for file in "$dir"/Screenshot\ [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9].[0-9][0-9].[0-9][0-9]*; do
            name="''${file:t}"
            new_name="''${name/#Screenshot /Screenshot-}"
            new_name="''${new_name/ /-}"
            target="$dir/$new_name"
            [[ "$file" == "$target" || -e "$target" ]] && continue
            mv "$file" "$target"
          done
        ''
      ];
      WatchPaths = [ "/Users/haruo/screenshots" ];
      RunAtLoad = true;
      StandardOutPath = "/Users/haruo/Library/Logs/normalize-screenshot-names.log";
      StandardErrorPath = "/Users/haruo/Library/Logs/normalize-screenshot-names.err.log";
    };
  };

  programs.vim = {
    enable = true;
    settings = {
      number = true;
      relativenumber = true;
      tabstop = 4;
      shiftwidth = 4;
      expandtab = true;
    };
    extraConfig = ''
      syntax on
      filetype plugin indent on
      set termguicolors
      colorscheme desert
      set cursorline
      set showmatch
      set incsearch
      set hlsearch
      set ignorecase
      set smartcase
    '';
  };
}
