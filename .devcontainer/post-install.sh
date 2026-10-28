#!/usr/bin/env bash
set -euo pipefail

install_dir="$HOME/.local/bin"
mkdir -p "$install_dir"

# Resolve a command on PATH, falling back to the known install locations that
# devcontainer.json may not have added to PATH yet. Prints the path when usable.
find_tool() {
  local tool="$1" candidate found=""
  shift

  if candidate="$(command -v "$tool" 2>/dev/null)" && [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  for candidate in "$@"; do
    if [[ -x "$candidate" ]] && "$candidate" --version >/dev/null 2>&1; then
      found="$candidate"
      break
    fi
  done
  if [[ -z "$found" ]]; then
    return 1
  fi
  printf '%s\n' "$found"
}

install_uv() {
  curl -LsSf https://astral.sh/uv/install.sh \
    | env UV_INSTALL_DIR="$install_dir" UV_NO_MODIFY_PATH=1 sh
}

install_micromamba() {
  local arch platform temp_dir
  arch="$(uname -m)"
  case "$arch" in
    x86_64)
      platform="linux-64"
      ;;
    aarch64 | arm64)
      platform="linux-aarch64"
      ;;
    *)
      printf 'Unsupported architecture for micromamba: %s\n' "$arch" >&2
      return 1
      ;;
  esac

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT

  curl -LsS "https://micro.mamba.pm/api/micromamba/${platform}/latest" \
    | tar -xj -C "$temp_dir" bin/micromamba
  install -m 0755 "$temp_dir/bin/micromamba" "$install_dir/micromamba"
}

install_bun() {
  curl -fsSL https://bun.sh/install \
    | env BUN_INSTALL="$HOME/.local" bash
}

# PDM ships as a standalone binary, and its installer links it into the
# directory given by -p, which the devcontainer already has on PATH.
install_pdm() {
  curl -sSL https://pdm-project.org/install.sh | bash -s -- -p "$install_dir"
}

# name:install function:fallback locations
tools=(
  "uv:install_uv:$install_dir/uv"
  "micromamba:install_micromamba:$install_dir/micromamba"
  "pdm:install_pdm:$install_dir/pdm"
  "bun:install_bun:$HOME/.bun/bin/bun"
)

installed=()
skipped=()
for tool_spec in "${tools[@]}"; do
  IFS=: read -r tool installer fallback <<<"$tool_spec"

  if tool_path="$(find_tool "$tool" "$fallback")"; then
    printf '%s already available at %s, skipping install\n' "$tool" "$tool_path"
    skipped+=("$tool")
    continue
  fi

  printf 'Installing %s...\n' "$tool"
  "$installer"
  if ! tool_path="$(find_tool "$tool" "$fallback")"; then
    printf '%s was installed but is not available at %s\n' "$tool" "$fallback" >&2
    exit 1
  fi
  installed+=("$tool")
done

if ((${#installed[@]})); then
  printf 'Installed %s\n' "${installed[*]}"
fi
if ((${#skipped[@]})); then
  printf 'Already present: %s\n' "${skipped[*]}"
fi
