[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# 1Password サービスアカウント。launchd の `sh -lc` はこのファイルを読む
# （.zshenv は読まない）ので、無人ジョブへ届かせるにはここにも要る。
# 詳細と副作用は ~/.config/nix-darwin/home.nix の envExtra のコメント参照。
if [ -r "$HOME/.config/op/service-account-token" ]; then
  export OP_SERVICE_ACCOUNT_TOKEN="$(tr -d '[:space:]' < "$HOME/.config/op/service-account-token")"
fi
