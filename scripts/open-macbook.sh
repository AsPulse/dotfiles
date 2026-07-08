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

for path in "$@"; do
  echo ">> Copying: $path → ${HOST}:${remote_dir}/"
  "$RSYNC" -a --info=progress2 -e "$SSH" -- "$path" "${HOST}:${remote_dir}/"
done

echo ">> Opening in Finder..."
"$SSH" "$HOST" "open -- '$remote_dir'"

echo ">> Done: ${HOST}:${remote_dir}"
