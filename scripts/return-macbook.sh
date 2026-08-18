set -euo pipefail

RSYNC="@rsync@"
SSH="@ssh@"
HOST="aspulses-macbook-air"

usage() {
  echo "Usage: ReturnMacbook <remote-directory> <local-directory>" >&2
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

remote_dir="${1%/}"
local_dir="${2%/}"

if [[ ! -d "$local_dir" ]]; then
  echo "Error: not a directory: $local_dir" >&2
  exit 1
fi

if ! "$SSH" "$HOST" "test -d $(printf '%q' "$remote_dir")"; then
  echo "Error: not found on ${HOST}: $remote_dir" >&2
  exit 1
fi

echo ">> Returning: ${HOST}:${remote_dir}/ → ${local_dir}/"
"$RSYNC" -a --info=progress2 -e "$SSH" -- "${HOST}:${remote_dir}/" "${local_dir}/"

echo ">> Done: $local_dir"
