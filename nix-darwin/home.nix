{ pkgs, lib, nixpkgs-llama-cpp, ... }:

let
  mattPocockSkills = pkgs.fetchFromGitHub {
    owner = "mattpocock";
    repo = "skills";
    rev = "b8be62ffacb0118fa3eaa29a0923c87c8c11985c";
    hash = "sha256-Qwuu27f95xgAJ4hdv/4TNahHhprCMIxl1H9f9ymEsno=";
  };

  aiderChat = pkgs.aider-chat.overridePythonAttrs (old: {
    dependencies = old.dependencies ++ [ pkgs.python3Packages.rsa ];
  });

  llamaCppPkgs = import nixpkgs-llama-cpp {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
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

  home.file.".local/bin/aider" = {
    source = "${lib.getExe aiderChat}";
    executable = true;
  };

  home.file.".agents/skills/grill-with-docs" = {
    source = "${mattPocockSkills}/skills/engineering/grill-with-docs";
    force = true;
  };

  home.file.".claude/skills/grill-with-docs" = {
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
    terminal_profile="Clear Dark"
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
    aiderChat
    pkgs.claude-code
    pkgs.claude-monitor
    pkgs.gh
    pkgs.nodejs
    pkgs.obsidian
    pkgs.ghq
    llamaCppPkgs.llama-cpp
    pkgs.peco
    pkgs.python3
    pkgs.thunderbird
    pkgs.tree
    pkgs.uv
    pkgs.vscode
    pkgs.ffmpeg
    pkgs.yt-dlp

    # Rust ツールチェーン（rust-overlay）。cargo/rustc/clippy/rustfmt/rust-analyzer を
    # 1 つの toolchain で提供し、iOS クロスターゲット std を同梱する（api-player の Tauri iOS ビルド用）。
    (pkgs.rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
      targets = [ "aarch64-apple-ios" "aarch64-apple-ios-sim" ];
    })

    # Tauri モバイル（iOS）ビルド用ツール。
    pkgs.cargo-tauri
    pkgs.cocoapods
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
      gemma-agent = "OLLAMA_API_BASE=http://127.0.0.1:11434 aider --model ollama_chat/gemma4:26b --chat-language Japanese --commit-language English --no-auto-commits";
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

  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
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

  # ComfyUI ローカルサーバを常駐化。venv 自体は Nix 管理外（uv で作成）のまま、
  # 起動だけ宣言的に。adult-imagegen-rust アプリが 127.0.0.1:8188 へ接続する。
  launchd.agents.comfyui = {
    enable = true;
    config = {
      Label = "com.haruo.comfyui";
      ProgramArguments = [
        "/Users/haruo/ComfyUI/.venv/bin/python"
        "/Users/haruo/ComfyUI/main.py"
      ];
      WorkingDirectory = "/Users/haruo/ComfyUI";
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
      StandardOutPath = "/Users/haruo/Library/Logs/comfyui.log";
      StandardErrorPath = "/Users/haruo/Library/Logs/comfyui.err.log";
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
