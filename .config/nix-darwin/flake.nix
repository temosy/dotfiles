{
  description = "haruo's darwin system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-llama-cpp.url = "github:NixOS/nixpkgs/3d8f0f3f72a6cd4d93d0ad13203f2ea1cb7e1456";
    # Rust ツールチェーン（iOS クロスターゲットを宣言的に追加するため）。
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nix-darwin, nixpkgs, home-manager, nixpkgs-llama-cpp, rust-overlay }:
  let
    # 全ホスト共通の構成。ホストごとの違いは引数で渡す。
    # isMainMac: vault を書く launchd ジョブや ComfyUI など、2 台で同時に
    # 動かしてはいけないものを有効にするホストか（home.nix 参照）。
    mkDarwin = { isMainMac }: nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            pkgs._1password-cli
            pkgs.git
          ];

          fonts.packages = [
            pkgs.source-han-code-jp
            # CrossOver（Wine）の DirectWrite は、日本語の文字が無いと「Noto Sans CJK JP」へ
            # フォールバックする。これが無いと WPF 製のアプリ（FFXV ベンチのランチャー等）で
            # かなが豆腐になる。Wine は可変フォントを正しく読めないことがあるので static 版。
            pkgs.noto-fonts-cjk-sans-static
          ];

          programs.zsh.enable = true;

          security.pam.services.sudo_local.touchIdAuth = true;

          system.primaryUser = "haruo";

          system.defaults = {
            NSGlobalDomain = {
              KeyRepeat = 2;
              InitialKeyRepeat = 15;
              ApplePressAndHoldEnabled = false;
              NSAutomaticWindowAnimationsEnabled = false;
              NSWindowResizeTime = 0.0;
              "com.apple.swipescrolldirection" = false;
            };
            dock = {
              mineffect = "scale";
              launchanim = false;
            };
            universalaccess = {
              reduceMotion = true;
            };
            screencapture = {
              include-date = true;
              location = "/Users/haruo/screenshots";
            };
            CustomUserPreferences = {
              "com.apple.finder" = {
                DisableAllAnimations = true;
              };
              "com.apple.dock" = {
                "expose-animation-duration" = 0.0;
              };
              "com.apple.screencapture" = {
                name = "Screenshot";
              };
            };
          };

          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          system.configurationRevision = self.rev or self.dirtyRev or null;
          system.stateVersion = 5;
          nixpkgs.hostPlatform = "aarch64-darwin";
          nixpkgs.config.allowUnfree = true;
          # rust-overlay を適用（home.nix で pkgs.rust-bin を使えるようにする）。
          nixpkgs.overlays = [
            rust-overlay.overlays.default
          ];

          users.users.haruo = {
            name = "haruo";
            home = "/Users/haruo";
          };
        })

        # 主機だけ: Windows 機（192.168.1.21）から移した常駐処理の受け皿（2026-10-16 オーナー判断
        # 「furikae 以外は Mac Studio で」）。中身（スクリプト・トークン・鍵）は system-kakari の
        # scripts/install-mac-studio.sh が置く。ここは「誰が・いつ動かすか」の宣言だけ。
        # 各 run.sh は同じ場所に ENABLED が無ければ何もせず終わるので、宣言を先に入れても
        # Windows と二重には動かない（切り替えは system-kakari の docs/MacStudioへ移す手順.md）。
        (nixpkgs.lib.mkIf isMainMac {
          # 毎時の論評・5 分おきの当番・Fedora からの ssh を受けるので、寝ない
          # （以前は sleep 1 で、アプリが止めていただけだった）。画面は従来どおり消える。
          power.sleep.computer = "never";

          # Claude の無人ジョブ専用のユーザー（2026-10-16 オーナー判断）。Fedora の鍵で入れる先を
          # haruo のシェルにしない・bypassPermissions の当番が vault や鍵に触れないようにするため。
          # パスワードは無い（ssh の鍵だけ。その鍵も command= で入口 kakari-remote に固定）。
          users.knownUsers = [ "kakari" ];
          users.users.kakari = {
            uid = 502;
            gid = 20;  # staff
            home = "/Users/kakari";
            createHome = true;
            shell = "/bin/zsh";
            isHidden = true;
            description = "system-kakari automation";
          };

          # ログインしていなくても動くようデーモンで、kakari として動かす。
          # 置き場が無いうち（install-mac-studio.sh の前）は何もしない。
          launchd.daemons.kakari-commentary.serviceConfig = {
            Label = "com.haruo.kakari-commentary";
            UserName = "kakari";
            ProgramArguments = [ "/bin/sh" "-c"
              "test -x /Users/kakari/commentary/run.sh || exit 0; exec /bin/bash /Users/kakari/commentary/run.sh" ];
            # 毎時 :45。Fedora の毎時レポート（:05）が拾う前に書き終わる
            StartCalendarInterval = [ { Minute = 45; } ];
            ProcessType = "Background";
          };
          launchd.daemons.kakari-renraku.serviceConfig = {
            Label = "com.haruo.kakari-renraku";
            UserName = "kakari";
            ProgramArguments = [ "/bin/sh" "-c"
              "test -x /Users/kakari/renraku/run.sh || exit 0; exec /bin/bash /Users/kakari/renraku/run.sh" ];
            # 5 分おき。自分宛ての新着が無ければ Claude は起こさない（renraku_watch.py）
            StartInterval = 300;
            ProcessType = "Background";
          };
        })

        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit nixpkgs-llama-cpp isMainMac;
          };
          home-manager.users.haruo = import ./home.nix;
        }
      ];
    };
  in {
    # 2026-10-16 に主機を MacBook Pro から Mac Studio へ移した。
    darwinConfigurations."Haruos-MacBook-Pro" = mkDarwin { isMainMac = false; };
    # 2026-10-16 夜に Mac Studio のホスト名を HaruonoMac-Studio → system-kakari-studio に変えた。
    # darwin-rebuild は LocalHostName（scutil --get LocalHostName）で構成を選ぶので、名前を変えたら
    # ここも直す（直さないと nix-up が「構成が無い」で止まる）。
    darwinConfigurations."system-kakari-studio" = mkDarwin { isMainMac = true; };
  };
}
