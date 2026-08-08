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

  outputs = { self, nix-darwin, nixpkgs, home-manager, nixpkgs-llama-cpp, rust-overlay }: {
    darwinConfigurations."Haruos-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            pkgs._1password-cli
            pkgs.git
          ];

          fonts.packages = [
            pkgs.source-han-code-jp
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

        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit nixpkgs-llama-cpp;
          };
          home-manager.users.haruo = import ./home.nix;
        }
      ];
    };
  };
}
