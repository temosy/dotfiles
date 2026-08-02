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
LOCK_REL=".config/nix-darwin/flake.lock"

# 失敗ログと破棄した lock の置き場。**プロセス終了後も残す**。
# 一時ディレクトリに置くと、失敗を調べたい人が読む前に消える。
KEEP="$HOME/.cache/nix-up"
mkdir -p "$KEEP"

# 引数
DO_UPDATE=1
CHECK_ONLY=0
case "${1:-}" in
  --no-update) DO_UPDATE=0 ;;
  # --check: lock の健全化とビルド検証だけ行い、switch も GC もしない。
  # sudo 無しで安全網そのものを試せるようにしておく（この安全網は
  # 2026-08-02 に「壊れた lock を復元する」欠陥を抱えたまま動いていた）。
  --check)     DO_UPDATE=0; CHECK_ONLY=1 ;;
esac

# build が cwd に result シンボリックリンクを作る。ストアパスを GC から
# 守り続けてしまうので、一時ディレクトリで実行して後で消す。
WORK="$(mktemp -d)"
BACKUP="$WORK/flake.lock.bak"
BUILDLOG="$WORK/build.log"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

say() { printf '%s\n' "$*" >&2; }

# ★安全網の基準は「commit 済みの lock」であって、ワークツリーの lock ではない。
#
#   2026-08-02、前回の実行が壊れた lock をワークツリーに残したまま終わった。
#   次の実行はその壊れた版をバックアップとして退避し、切り戻し先そのものが
#   壊れていたため「現行 lock でも失敗する＝home.nix 側の問題」と誤診断した。
#   実際には home.nix は正常で、commit 済みの lock は普通にビルドできた。
#
#   未コミットの lock は前回の異常終了の痕跡とみなして捨てる。捨てた版は
#   $KEEP に残すので、意図的な手編集だった場合も戻せる。
if git -C "$HOME" rev-parse --git-dir >/dev/null 2>&1 &&
   ! git -C "$HOME" diff --quiet -- "$LOCK_REL" 2>/dev/null; then
  cp "$LOCK" "$KEEP/flake.lock.discarded"
  git -C "$HOME" checkout -- "$LOCK_REL"
  say "⚠ nix-up: 未コミットの flake.lock が残っていた（前回の異常終了の痕跡）。"
  say "   commit 済みの版に戻して進む。捨てた版: ${KEEP}/flake.lock.discarded"
  say ""
fi

# ビルド失敗の**原因**を出す。`Cannot build ...` の連鎖は依存が落ちた結果で
# あって原因ではないので、実際に落ちた builder の出力（`> ` 始まり）を探す。
show_failure() {
  cp "$BUILDLOG" "$KEEP/build.log"
  say "   失敗した derivation:"
  grep -oE "Cannot build '[^']+'" "$BUILDLOG" | head -5 | sed 's/^/     /' >&2
  # ★grep の結果を判定に使うときは、パイプの終了状態を見ない。
  #   `grep ... | sed` の $? は sed のもので、常に 0 になる。
  if grep -qE '^[[:space:]]+> ' "$BUILDLOG"; then
    say "   builder の出力（末尾15行）:"
    grep -E '^[[:space:]]+> ' "$BUILDLOG" | tail -15 | sed 's/^/     /' >&2
  else
    say "   ログ末尾:"
    tail -15 "$BUILDLOG" | sed 's/^/     /' >&2
  fi
  say "   全文: ${KEEP}/build.log"
}

build_ok() {
  # $1 = 表示用ラベル。成功なら 0。
  ( cd "$WORK" && darwin-rebuild build --flake "$FLAKE" ) > "$BUILDLOG" 2>&1
}

updated=0
discarded=0   # 更新を試したが壊れていて破棄した

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
      # ★復元を最初に行う。表示より前。
      #   2026-08-02、この cp を装飾的な say の後ろに置いていたため、say の
      #   1行が `unbound variable` で落ちて **lock が壊れたまま残った**。
      #   安全側に戻す操作を、表示の成否に依存させない。
      cp "$BACKUP" "$LOCK"
      discarded=1
      say ""
      say "⚠ nix-up: 更新後の nixpkgs でビルドが失敗した。**更新を破棄して現行 lock で適用する。**"
      show_failure
      say ""
      say "   上流が直ったか試すには、後日もう一度 nix-up を実行する。"
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
    show_failure
    say ""
    # ★ここで原因を断定しない。2026-08-02、「home.nix 側の問題の可能性が高い」と
    #   決めつけていたが、実際は残っていた壊れた lock が原因で home.nix は正常だった。
    say "   flake.nix / home.nix の編集ミスか、commit 済み lock の nixpkgs 自体が"
    say "   壊れているかのどちらか。上のログで切り分ける。"
    exit 1
  fi
  say "  ✓ ビルド成功"
fi

if [ "$CHECK_ONLY" = 1 ]; then
  say "nix-up: --check なのでここで終了（switch も GC もしない）"
  exit 0
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
      say "nix-up: dotfiles が master に居ないので flake.lock の commit は見送る（現在: ${b}）"
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

# GC は「更新を破棄していないとき」だけ。
#
# ★判定は switch の成否ではなく「破棄したか」で行う。
#   2026-08-02、条件が switch の成否だったため、更新を破棄した回でも GC が走り、
#   検証のために正常にビルドできていた新 nixpkgs 側の依存まで 1.4GiB 消した。
#   上流が壊れている間は毎回それを再ビルドすることになる。
#   破棄した回の成果物は「次の挑戦で再利用したいもの」そのものなので残す。
#
#   上流が長く壊れていて store を掃除したくなったら nix-switch（--no-update）を使う。
if [ "$discarded" = 1 ]; then
  say "nix-up: 更新を破棄した回なので GC しない（次回の再ビルドを避けるため）"
  say "        掃除したいときは nix-switch を使う"
  exit 0
fi

say "→ 古い世代を掃除（14日より前）"
sudo nix-collect-garbage --delete-older-than 14d
