set -euo pipefail

RSYNC="@rsync@"
SSH="@ssh@"
HOST="aspulses-macbook-air"

usage() {
  echo "Usage: OpenMacbook <file-or-directory>..." >&2
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

for path in "$@"; do
  if [[ ! -e "$path" ]]; then
    echo "Error: not found: $path" >&2
    exit 1
  fi
done

remote_dir="/tmp/open-macbook-$(date +%Y%m%d%H%M%S)-$$"

"$SSH" "$HOST" "mkdir -p -- '$remote_dir'"

return_commands=()

for path in "$@"; do
  echo ">> Copying: $path → ${HOST}:${remote_dir}/"
  # 末尾スラッシュ付きだと rsync が中身だけを展開してしまうため、絶対パスに正規化してから渡す
  src="$(realpath -- "$path")"
  "$RSYNC" -a --info=progress2 -e "$SSH" -- "$src" "${HOST}:${remote_dir}/"

  if [[ -d "$src" ]]; then
    return_commands+=(
      "ReturnMacbook $(printf '%q' "${remote_dir}/$(basename -- "$src")") $(printf '%q' "$src")"
    )
  fi
done

echo ">> Opening in Finder..."
"$SSH" "$HOST" "open -- '$remote_dir'"

echo ">> Done: ${HOST}:${remote_dir}"

if [[ ${#return_commands[@]} -gt 0 ]]; then
  echo
  echo ">> To bring the contents back:"
  for cmd in "${return_commands[@]}"; do
    echo "     $cmd"
  done
fi
