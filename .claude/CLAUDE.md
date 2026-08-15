# 全プロジェクト共通の指示（haruo）

**出典は `~/AGENTS.md`**（temosy/dotfiles で追跡）。Codex はホーム配下でそれを直接読む。
Claude Code は読まないので、要点だけをここに置く。**変更するときは両方直すこと。**

## 手を動かす前に、道具を確認する

MCP ツールは**名前だけが200個以上並ぶ**形で渡され（deferred）、説明文が付かない。意識して
探さない限り埋もれるので、「そんな手段は無い」と判断する前に必ず ToolSearch で確かめること。

| 用事 | 使うもの |
|---|---|
| Thunderbird のメール・フォルダ・カレンダー・連絡先 | `mcp__thunderbird-mail__*` |
| ログイン済み Chrome が要るブラウザ操作 | `mcp__claude-in-chrome__*` |
| 使い捨てのブラウザ検証 | Browser ペイン / `mcp__playwright__*` |
| macOS のネイティブアプリ操作 | `mcp__computer-use__*` / `mcp__MacOS-MCP__*` |
| 過去の会話を思い出す | `mcp__episodic-memory__*` |

Gmail・Google カレンダー・Google Drive・Vercel・Figma も繋がっているが、**サーバー名が
UUID** なので名前では気づけない。ToolSearch にキーワード（`gmail` / `calendar` / `drive`
など）を投げて引き当てること。

**アプリのデータを直接いじる前に、そのアプリの MCP が無いか先に見る。** Thunderbird の
メールを `rm` と GUI 操作で片付けようとして失敗した実績がある（2026-08-15。どちらも権限
判定で止められ、MCP の `deleteFolder` で片付いた）。

## Git / PR

**マージ済みブランチは削除する。確認を取らずに消してよい**（毎回聞かれるのが鬱陶しい・
2026-08-13）。**ただし機械で確かめてから消すこと。** 判定は「ローカルの tip が、
*マージ済み* PR の head コミットと一致するか」。これならローカルに置き去りの
コミットが無いことまで言える。

```bash
b=<branch>
[ "$(git rev-parse "$b")" = "$(gh pr list --head "$b" --state merged --json headRefOid -q '.[0].headRefOid')" ] \
  && git branch -D "$b"
```

squash マージだと SHA が変わるので `git branch --merged` や `git log main..<branch>` は
マージ済みを未マージと言う。`gh` は本当のことを知っている。

**差分（`git diff --numstat`）を主判定に使わないこと。** 3通りの読み違いを実際に踏んだ:

- **`origin/<branch>` を指すと fatal になり stdout が空になる**（2026-08-08）。
  `delete_branch_on_merge` が有効なのでリモートブランチはもう無い。エラーは stderr に
  出るため、出力を眺めただけでは「差分なし」と区別が付かない。
- **main が先に進んでいると、マージ済みでも差分は空にならない**（2026-08-08）。
  後続 PR が足した行が「削除」として出る。これは削除して安全なケース。
- **ブランチが触ったファイルに絞っても救われない**（2026-08-13）。後続 PR が同じ
  ファイルを書き換えていると、**マージ済みの行が「挿入」として出る**。実際に、
  完全に main に入っているブランチが 62 挿入と出た（次の PR がその関数を差し替えたため）。

PR が存在しない場合だけ差分判定に落とす。そのときも上の3つを念頭に読む。

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
