#!/usr/bin/env bash
# Runs a command (usually an npm install) with git redirected from the PCX-Network forks on
# GitHub to local checkouts, so the github:PCX-Network/...#<sha> pins in runner-package resolve
# before those commits are pushed. npm records the same git+ssh://git@github.com/... resolved
# URLs it would after a push, so the lockfile it writes is the one to commit.
#
#   scripts/with-local-forks.sh [--forks-dir DIR] <command...>
#
# DIR (default: the directory containing this repo) must hold checkouts named minecraft-data,
# node-minecraft-protocol and mineflayer, each with the pinned commit checked out as HEAD:
# npm clones a pinned commit from a local path only when it is the advertised HEAD.
set -euo pipefail

FORKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ "${1:-}" == "--forks-dir" ]]; then
    FORKS_DIR="$(cd "$2" && pwd)"
    shift 2
fi
if [[ $# -eq 0 ]]; then
    sed -n '2,12p' "${BASH_SOURCE[0]}"
    exit 2
fi

CONFIG="$(mktemp)"
trap 'rm -f "$CONFIG"' EXIT
if [[ -f "${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}" ]]; then
    printf '[include]\n\tpath = %s\n' "${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}" >> "$CONFIG"
fi
for repo in minecraft-data node-minecraft-protocol mineflayer; do
    if [[ ! -d "$FORKS_DIR/$repo/.git" ]]; then
        echo "with-local-forks: $FORKS_DIR/$repo is not a git checkout" >&2
        exit 1
    fi
    printf '[url "file://%s/%s"]\n' "$FORKS_DIR" "$repo" >> "$CONFIG"
    for prefix in "https://github.com/PCX-Network/$repo" "ssh://git@github.com/PCX-Network/$repo" "git@github.com:PCX-Network/$repo"; do
        printf '\tinsteadOf = %s.git\n\tinsteadOf = %s\n' "$prefix" "$prefix" >> "$CONFIG"
    done
done

GIT_CONFIG_GLOBAL="$CONFIG" "$@"
