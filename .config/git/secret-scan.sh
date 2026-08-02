#!/usr/bin/env bash
# dotfiles に秘密情報が混入していないか検査する。
#
#   ~/.config/git/secret-scan.sh            # ステージ済みの変更だけ検査（pre-commit 用）
#   ~/.config/git/secret-scan.sh --history  # 全履歴を検査（棚卸し用）
#   ~/.config/git/secret-scan.sh --worktree # 作業ツリーの追跡ファイルを検査
#
# **このスクリプトが存在する理由**:
#
# ~/ 自体が temosy/dotfiles のワークツリーで、しかも public リポジトリ。
# API キー・token・credential を1回でも commit すると、消しても履歴に残る。
# 目視に頼らず機械で止める。
#
# ★★ 自己テストを必ず先に走らせる ★★
#
# 2026-08-02、この検査を手で書いたとき **検査自体が壊れているのに「異常なし」を
# 返した**。zsh は未クオートの変数展開を単語分割しないため、コミット SHA の一覧が
# 1 引数として git に渡り、git がエラーを返していたのを `2>/dev/null` で捨てていた。
# 陽性対照のつもりで数えていた「41 件ヒット」も、実体は 41 行のエラー出力だった。
#
# 検査が沈黙することと、問題が無いことは違う。**既知の偽シークレットを必ず検出
# できることを毎回確認してから**本番の検査に進む（self_test）。この順序を崩さない。
#
# bash で書く（zsh の単語分割の差異を踏まないため）。依存は git と grep だけ。
set -uo pipefail

MODE="${1:---staged}"
REPO="${HOME}"

# 検出パターン。**値の形が決まっているものだけをここに置く。**
# 「password」のような語そのものは参照（op read "op://.../password"）でも当たるので、
# ここではなく後段の ASSIGN_RE で値の有無まで見る。
declare -a PATTERNS=(
  "1Password サービスアカウント|ops_[A-Za-z0-9]{20,}"
  "GitHub トークン|(ghp|gho|ghu|ghs)_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}"
  "OpenAI/Anthropic APIキー|sk-(ant|proj|or)-[A-Za-z0-9_-]{20,}"
  "AWS アクセスキー|AKIA[0-9A-Z]{16}"
  "Google OAuth シークレット|GOCSPX-[A-Za-z0-9_-]{20,}"
  "Telegram Bot トークン|[0-9]{8,10}:[A-Za-z0-9_-]{35}"
  "秘密鍵ブロック|BEGIN (RSA|OPENSSH|DSA|EC|PGP) PRIVATE KEY"
  "Slack トークン|xox[baprs]-[A-Za-z0-9-]{10,}"
  "Stripe 秘密鍵|sk_(live|test)_[A-Za-z0-9]{20,}"
)

# 値を伴う代入。参照だけ（op read / 環境変数名だけ）は当てない。
ASSIGN_RE='(password|passwd|secret|api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret)[[:space:]]*[=:][[:space:]]*["'"'"']?[A-Za-z0-9/+_.-]{12,}'

# 名前からして中身が秘密のファイル。ここに載るパスは内容を問わず弾く。
FILENAME_RE='(^|/)(id_rsa|id_dsa|id_ecdsa|id_ed25519|\.netrc|\.pgpass|authinfo)$|\.(pem|key|p12|pfx|jks|keystore)$|(^|/)\.env(\.|$)|service-account-token'

fail=0

note() { printf '%s\n' "$*" >&2; }

# ── 自己テスト ────────────────────────────────────────────────
# 既知の偽シークレットを検出できなければ、この検査は信用できない。
# **本番検査より前に落とす。** 静かに素通りするより、うるさく止まるほうが安全。
self_test() {
  local fake_ok=0 clean_ok=0
  # ★偽シークレットは実行時に組み立てる。リテラルで書くと**この検査自身が
  #   自分を検出して commit を止める**（2026-08-02 に実際に踏んだ）。
  #   下の行に `ops_` に続く英数字の並びが現れないようにしてある。
  local pfx='ops'
  local fake="${pfx}_FAKEfake0123456789abcdefghijklmnopqrstuvwxyz"
  local clean='this line has no secrets at all'
  for entry in "${PATTERNS[@]}"; do
    local re="${entry#*|}"
    if printf '%s\n' "$fake" | grep -qE "$re"; then fake_ok=1; break; fi
  done
  for entry in "${PATTERNS[@]}"; do
    local re="${entry#*|}"
    if printf '%s\n' "$clean" | grep -qE "$re"; then clean_ok=1; break; fi
  done
  if [ "$fake_ok" -ne 1 ]; then
    note "secret-scan: 自己テスト失敗（偽シークレットを検出できない）。検査を信用できないので中止する。"
    exit 2
  fi
  if [ "$clean_ok" -ne 0 ]; then
    note "secret-scan: 自己テスト失敗（無害な行を誤検出する）。中止する。"
    exit 2
  fi
}

# 与えられたテキストを検査する。$1 = 表示用のラベル
check_text() {
  local label="$1" text hit
  text="$(cat)"
  [ -z "$text" ] && return 0
  for entry in "${PATTERNS[@]}"; do
    local name="${entry%%|*}" re="${entry#*|}"
    if printf '%s' "$text" | grep -qE "$re"; then
      note "  ✗ $label: ${name} らしき値を検出"
      fail=1
    fi
  done
  if printf '%s' "$text" | grep -qiE "$ASSIGN_RE"; then
    note "  ✗ $label: 値を伴う秘密情報の代入を検出"
    fail=1
  fi
}

check_filenames() {
  local label="$1" f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if printf '%s' "$f" | grep -qE "$FILENAME_RE"; then
      note "  ✗ $label: 秘密情報を含むファイル名 — $f"
      fail=1
    fi
  done
}

self_test

cd "$REPO" || exit 2

case "$MODE" in
  --staged)
    note "secret-scan: ステージ済みの変更を検査中..."
    # ★パイプで関数へ渡さない。パイプの各段はサブシェルなので、関数内で立てた
    #   fail=1 が親へ戻らず「検出したのに問題なし」で通る（2026-08-02 に実際に踏んだ）。
    #   プロセス置換なら関数は現在のシェルで動く。
    check_filenames "staged" < <(git diff --cached --name-only --diff-filter=ACMR)
    # 追加された行だけ見る（既存行の再掲で毎回落ちないように）
    check_text "staged" < <(git diff --cached -U0 --diff-filter=ACMR | grep '^+' | grep -v '^+++')
    ;;
  --worktree)
    note "secret-scan: 追跡ファイル（作業ツリー）を検査中..."
    check_filenames "worktree" < <(git ls-files)
    check_text "worktree" < <(git ls-files -z | xargs -0 cat 2>/dev/null)
    ;;
  --history)
    note "secret-scan: 全履歴を検査中..."
    # **配列で渡す。** 変数を裸で展開すると shell によっては 1 引数になり、
    # git がエラーを返すのを握り潰して「異常なし」に化ける（冒頭の注記参照）。
    mapfile -t REVS < <(git rev-list --all)
    if [ "${#REVS[@]}" -eq 0 ]; then
      note "secret-scan: コミットが無い"; exit 0
    fi
    # 陽性対照: 必ず在る文字列が引けるか。引けなければ検査系が壊れている。
    if ! git grep -l -I -E 'nixpkgs' "${REVS[@]}" >/dev/null 2>&1; then
      note "secret-scan: 履歴検索の陽性対照に失敗した。検査を信用できないので中止する。"
      exit 2
    fi
    check_filenames "history" < <(git log --all --pretty=format: --name-only | sort -u | grep -v '^$')
    for entry in "${PATTERNS[@]}"; do
      name="${entry%%|*}"; re="${entry#*|}"
      hits="$(git grep -l -I -E "$re" "${REVS[@]}" 2>/dev/null | sed 's/^[0-9a-f]\{40\}://' | sort -u)"
      if [ -n "$hits" ]; then
        note "  ✗ history: ${name} らしき値 — 以下のファイル"
        printf '%s\n' "$hits" | sed 's/^/      /' >&2
        fail=1
      fi
    done
    hits="$(git grep -l -I -iE "$ASSIGN_RE" "${REVS[@]}" 2>/dev/null | sed 's/^[0-9a-f]\{40\}://' | sort -u)"
    if [ -n "$hits" ]; then
      note "  ✗ history: 値を伴う代入 — 以下のファイル"
      printf '%s\n' "$hits" | sed 's/^/      /' >&2
      fail=1
    fi
    ;;
  *)
    note "使い方: $0 [--staged|--worktree|--history]"; exit 2
    ;;
esac

if [ "$fail" -ne 0 ]; then
  note ""
  note "secret-scan: 秘密情報の疑いを検出した。commit を中止する。"
  note "  誤検出なら: git commit --no-verify で通せる（内容を確認してから）。"
  exit 1
fi

note "secret-scan: 問題なし"
exit 0
