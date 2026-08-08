# 全プロジェクト共通の指示（haruo）

**出典は `~/AGENTS.md`**（temosy/dotfiles で追跡）。Codex はホーム配下でそれを直接読む。
Claude Code は読まないので、要点だけをここに置く。**変更するときは両方直すこと。**

## Git / PR

**マージ済みブランチは削除する。** 削除前に **ブランチ側の挿入が 0** であることを確認する
（squash マージだと SHA が変わるので `git branch --merged` や `git log main..<branch>` では
判定できない）。削除の実行前には確認を取る。

```bash
git diff --numstat origin/main <branch> | awk '$1 != 0'   # 何も出なければ削除して安全
```

`--numstat` の1列目が挿入行数。**ブランチにあって main に無いもの**がゼロなら、中身は
完全に main に入っている。**「差分が空」で判定しないこと**（2026-08-08 に両方踏んだ）:

- **`origin/<branch>` を指すと fatal になり stdout が空になる。** `delete_branch_on_merge`
  が有効なのでマージ直後にリモートブランチはもう無い。エラーは stderr に出るため、
  出力を眺めただけでは「差分なし」と区別が付かない。**ローカルのブランチ名を渡す。**
- **main が先に進んでいると、マージ済みでも差分は空にならない。** 後続 PR が足した行が
  「削除」として出る。これは削除して安全なケース。

**新規リポジトリでは `delete_branch_on_merge` を有効にする。**

```bash
gh api -X PATCH repos/<owner>/<repo> -F delete_branch_on_merge=true
```

**PR は積まない。** 先行 PR のマージを待って main 直行にする。積んだ場合は、先行 PR の
マージ後に base が main へ切り替わったかを `gh pr view <n> --json baseRefName` で確認する。
マージ済みブランチが残っていると GitHub は自動再ターゲットせず、**マージしたつもりの
変更が main に入らない**（2026-07-29 に実際に発生）。

**「マージ完了」と言われたら、実際に main へ入ったかを見る。** `git log origin/main` と、
新規ファイルなら `git cat-file -e origin/main:<path>` で確認する。

詳細と経緯: `~/Documents/Startup/開発運用ルール_GitとPRの扱い.md`

## ホームディレクトリ

`~/` 自体が temosy/dotfiles のワークツリー。ホーム全体への `git add -A` や広範囲の
`git add -f` は禁止。API キー・token・credential・cookie・履歴・キャッシュは追跡しない。
追跡ファイルを変えたら `~/` で commit して `origin master` へ push するまでが1つの作業。
手順の全文は `~/AGENTS.md`。
