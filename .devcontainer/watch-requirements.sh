#!/usr/bin/env bash
set -euo pipefail

script_path="$(realpath "${BASH_SOURCE[0]}")"
repo_root="$(dirname "$(dirname "$script_path")")"
requirements_file="$repo_root/requirements.txt"
watcher_log="${TMPDIR:-/tmp}/stupidinfer-requirements-watcher.log"
lock_file="${TMPDIR:-/tmp}/stupidinfer-requirements-watcher.lock"

generate_manifests() {
  local temp_dir project_name python_constraint python_spec
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  project_name="$(basename "$repo_root" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')"
  python_constraint="$(awk 'tolower($1) == "python-must" { $1 = ""; sub(/^[[:space:]]+/, ""); print; count++ } END { if (count > 1) exit 1 }' "$requirements_file" | tr -d '[:space:]')"
  python_spec="python${python_constraint}"

  mkdir "$temp_dir/project"
  local uv_init_args=(init --name "$project_name")
  if [[ -n "$python_constraint" ]]; then
    uv_init_args+=(--python "$python_constraint")
  fi
  uv "${uv_init_args[@]}" "$temp_dir/project"

  sed '/^[[:space:]]*python-must\([[:space:]<>=!~]\|$\)/Id' "$requirements_file" \
    > "$temp_dir/requirements.txt"
  if [[ -s "$temp_dir/requirements.txt" ]]; then
    uv add --project "$temp_dir/project" --no-sync --requirements "$temp_dir/requirements.txt"
  fi

  export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-$HOME/.cache/mamba}"
  micromamba create --yes --prefix "$temp_dir/environment" --channel conda-forge "$python_spec" pip
  micromamba run --prefix "$temp_dir/environment" python -m pip install \
    --disable-pip-version-check -r "$temp_dir/requirements.txt"
  micromamba env export --prefix "$temp_dir/environment" --no-builds \
    | sed -E "s|^name:.*$|name: $project_name|; /^prefix:[[:space:]]/d" \
      > "$temp_dir/environment.yml"

  cp "$temp_dir/project/pyproject.toml" "$repo_root/pyproject.toml"
  cp "$temp_dir/environment.yml" "$repo_root/environment.yml"
}

if [[ "${1:-}" == "--once" ]]; then
  generate_manifests
  exit
fi

if [[ "${1:-}" == "--watch-loop" ]]; then
  exec 9>"$lock_file"
  flock -n 9 || exit 0

  last_hash="$(sha256sum "$requirements_file" | awk '{print $1}')"
  while true; do
    sleep 2
    current_hash="$(sha256sum "$requirements_file" | awk '{print $1}')"
    if [[ "$current_hash" != "$last_hash" ]]; then
      sleep 1
      generate_manifests || true
      last_hash="$(sha256sum "$requirements_file" | awk '{print $1}')"
    fi
  done
fi

generate_manifests
nohup bash "$script_path" --watch-loop >"$watcher_log" 2>&1 </dev/null &