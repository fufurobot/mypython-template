#!/usr/bin/env bash
set -euo pipefail

install_dir="$HOME/.local/bin"
mkdir -p "$install_dir"

curl -LsSf https://astral.sh/uv/install.sh \
  | env UV_INSTALL_DIR="$install_dir" UV_NO_MODIFY_PATH=1 sh

case "$(uname -m)" in
  x86_64)
    micromamba_platform="linux-64"
    ;;
  aarch64 | arm64)
    micromamba_platform="linux-aarch64"
    ;;
  *)
    printf 'Unsupported architecture for micromamba: %s\n' "$(uname -m)" >&2
    exit 1
    ;;
esac

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

curl -LsS "https://micro.mamba.pm/api/micromamba/${micromamba_platform}/latest" \
  | tar -xj -C "$temp_dir" bin/micromamba
install -m 0755 "$temp_dir/bin/micromamba" "$install_dir/micromamba"

printf 'Installed uv and micromamba in %s\n' "$install_dir"