#!/usr/bin/env bash
# nix-darwin を更新して適用する。**壊れた更新はシステムに触れさせない。**
#
#   nix-up            # 更新を試し、駄目なら現行 lock のまま適用
#   nix-up --no-update  # 更新せず、現行 lock で適用するだけ
#
# **このスクリプトが存在する理由**:
#
# 旧 nix-up は `nix flake update && sudo darwin-rebuild switch && ...` の直列だった。
# 上流 nixpkgs が壊れていると（2026-08-02 の libfaketime のように）switch の手前で
# 落ちるので**システムは無事**だが、flake.lock は更新済みのまま残る。そのため
# 実行するたび同じ所で止まり、毎回手で `git checkout -- flake.lock` して
# `darwin-rebuild switch` を打ち直す羽目になった。
#
# ここでは switch の前に **build で検証**し、駄目なら lock を戻してから
# 現行版で適用する。上流が壊れていても「適用は進み、更新だけ見送られる」。
#
# 使うのは build → switch の順。build は sudo 不要でシステムを変更しないので、
# 壊れた設定が activation まで届かない。

set -uo pipefail

FLAKE="$HOME/.config/nix-darwin"
LOCK="$FLAKE/flake.lock"

# 引数
DO_UPDATE=1
[ "${1:-}" = "--no-update" ] && DO_UPDATE=0

# build が cwd に result シンボリックリンクを作る。ストアパスを GC から
# 守り続けてしまうので、一時ディレクトリで実行して後で消す。
WORK="$(mktemp -d)"
BACKUP="$WORK/flake.lock.bak"
BUILDLOG="$WORK/build.log"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

say() { printf '%s\n' "$*" >&2; }

build_ok() {
  # $1 = 表示用ラベル。成功なら 0。
  ( cd "$WORK" && darwin-rebuild build --flake "$FLAKE" ) > "$BUILDLOG" 2>&1
}

updated=0

if [ "$DO_UPDATE" = 1 ]; then
  cp "$LOCK" "$BACKUP"

  say "→ nix flake update"
  if ! nix flake update --flake "$FLAKE"; then
    say "nix-up: flake update に失敗した（ネットワーク？）。更新は見送って現行 lock で進む。"
    cp "$BACKUP" "$LOCK"
  else
    say "→ 更新後の設定をビルド検証（システムには触らない）"
    if build_ok; then
      updated=1
      say "  ✓ ビルド成功。更新を採用する。"
    else
      say ""
      say "⚠ nix-up: 更新後の nixpkgs でビルドが失敗した。**更新を破棄して現行 lock で適用する。**"
      say "   失敗した derivation:"
      grep -oE "Cannot build '[^']+'" "$BUILDLOG" | sed 's/^/     /' | head -5 >&2
      grep -E "^\s+> (can't find file to patch|error:|.*[Ee]rror)" "$BUILDLOG" | head -3 | sed 's/^/     /' >&2
      say ""
      say "   上流が直ったか試すには、後日もう一度 nix-up を実行する。"
      say "   ログ: $BUILDLOG（このプロセス終了で消える）"
      cp "$BACKUP" "$LOCK"
    fi
  fi
fi

# ここまでで lock は「ビルドが通ることを確認済み」か「更新前の既知の良い版」。
# 更新を見送った場合も現行版のビルドを一度確かめてから switch する
# （home.nix 自体の編集ミスを activation の手前で捕まえるため）。
if [ "$updated" = 0 ]; then
  say "→ 現行 lock でビルド検証"
  if ! build_ok; then
    say ""
    say "✗ nix-up: 現行の設定がビルドできない。**適用せず中止する。**"
    say "   上流ではなく flake.nix / home.nix 側の問題の可能性が高い:"
    tail -20 "$BUILDLOG" | sed 's/^/     /' >&2
    exit 1
  fi
  say "  ✓ ビルド成功"
fi

say "→ sudo darwin-rebuild switch"
if ! sudo darwin-rebuild switch --flake "$FLAKE"; then
  say "✗ nix-up: switch に失敗した。"
  exit 1
fi

# flake.lock を更新できたときだけ dotfiles へ記録する。
if [ "$updated" = 1 ]; then
  (
    cd "$HOME" || exit 1
    b="$(git symbolic-ref --short HEAD)"
    if [ "$b" != master ]; then
      say "nix-up: dotfiles が master に居ないので flake.lock の commit は見送る（現在: $b）"
      exit 0
    fi
    git diff --quiet -- .config/nix-darwin/flake.lock && { say "nix-up: flake.lock に差分なし"; exit 0; }
    git add .config/nix-darwin/flake.lock &&
      git commit -m "Update flake inputs $(date +%F)" &&
      git push origin master
  )
else
  say "nix-up: flake.lock は更新していない（上流が直ったら次回の nix-up で採用される）"
fi

# GC は成功したときだけ。失敗した直後に走らせると、再挑戦のたびに
# ビルド成果物を捨てて時間を無駄にする（2026-08-02 に 2回で計 2.3GB 捨てた）。
say "→ 古い世代を掃除（14日より前）"
sudo nix-collect-garbage --delete-older-than 14d
