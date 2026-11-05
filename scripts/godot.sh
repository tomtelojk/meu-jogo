#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Keep Godot's profile writable in the managed cloud machine, without changing HOME.
export XDG_DATA_HOME="${XDG_DATA_HOME:-$project_root/.runtime/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$project_root/.runtime/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$project_root/.runtime/cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
exec godot --path "$project_root" "$@"
