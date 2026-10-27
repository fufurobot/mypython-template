#!/usr/bin/env bash
set -euo pipefail

script_path="$(realpath "${BASH_SOURCE[0]}")"
repo_root="$(dirname "$(dirname "$script_path")")"
requirements_file="$repo_root/requirements.txt"
pyproject_file="$repo_root/pyproject.toml"
environment_file="$repo_root/environment.yml"
env_file="$repo_root/.env"
watcher_log="${TMPDIR:-/tmp}/stupidinfer-dependencies-watcher.log"
lock_file="${TMPDIR:-/tmp}/stupidinfer-dependencies-watcher.lock"

project_name="$(basename "$repo_root" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')"

load_dependency_manager() {
  local manager="" line value

  if [[ -f "$env_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?DEPENDENCY_MANAGER[[:space:]]*=(.*)$ ]]; then
        value="${BASH_REMATCH[2]}"
        value="${value%%#*}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then
          value="${value:1:${#value}-2}"
        fi
        manager="$value"
      fi
    done < "$env_file"
  fi

  manager="${manager:-${DEPENDENCY_MANAGER:-}}"
  manager="${manager,,}"
  case "$manager" in
    uv)
      printf 'uv\n'
      ;;
    mamba | micromamba)
      printf 'micromamba\n'
      ;;
    "")
      if [[ -d "$repo_root/notebooks" ]]; then
        printf 'micromamba\n'
      else
        printf 'uv\n'
      fi
      ;;
    *)
      printf 'Unsupported DEPENDENCY_MANAGER value: %s (use uv or micromamba)\n' "$manager" >&2
      return 1
      ;;
  esac
}

read_python_constraint() {
  if [[ ! -f "$requirements_file" ]]; then
    return 0
  fi
  awk 'tolower($1) == "python-must" { $1 = ""; sub(/^[[:space:]]+/, ""); print; count++ } END { if (count > 1) exit 1 }' "$requirements_file" \
    | tr -d '[:space:]'
}

require_requirements_for_bootstrap() {
  if [[ ! -f "$requirements_file" ]]; then
    printf 'Cannot initialize the selected dependency manifest: %s is missing\n' "$requirements_file" >&2
    return 1
  fi
}

initialize_uv_manifest() {
  local python_constraint temp_requirements
  python_constraint="$(read_python_constraint)"

  local uv_init_args=(init --bare --name "$project_name")
  if [[ -n "$python_constraint" ]]; then
    uv_init_args+=(--python "$python_constraint")
  fi
  uv "${uv_init_args[@]}" "$repo_root"

  temp_requirements="$1/requirements.txt"
  sed '/^[[:space:]]*python-must\([[:space:]<>=!~]\|$\)/Id' "$requirements_file" > "$temp_requirements"
  if [[ -s "$temp_requirements" ]]; then
    uv add --project "$repo_root" --no-sync --requirements "$temp_requirements"
  fi
}

initialize_micromamba_manifest() {
  python3 - "$requirements_file" "$environment_file" "$project_name" "$(read_python_constraint)" <<'PY'
import json
import sys

requirements_path, environment_path, project_name, python_constraint = sys.argv[1:]
dependencies = []
with open(requirements_path, encoding="utf-8") as requirements:
    for line in requirements:
        requirement = line.strip()
        if not requirement or requirement.startswith("#") or requirement.lower().startswith("python-must"):
            continue
        dependencies.append(requirement)

with open(environment_path, "w", encoding="utf-8") as environment:
    environment.write(f"name: {project_name}\nchannels:\n  - conda-forge\ndependencies:\n")
    environment.write(f"  - python{python_constraint}\n  - pip\n")
    if dependencies:
        environment.write("  - pip:\n")
        for dependency in dependencies:
            environment.write(f"      - {json.dumps(dependency)}\n")
PY
}

sync_uv_project() (
  local temp_dir python_constraint
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT

  if [[ ! -f "$pyproject_file" ]]; then
    require_requirements_for_bootstrap
    initialize_uv_manifest "$temp_dir"
  fi

  uv sync --project "$repo_root"

  uv export --project "$repo_root" --format requirements-txt --no-header --no-emit-project \
    --output-file "$temp_dir/requirements.txt"

  python_constraint="$(read_python_constraint)"
  if [[ -z "$python_constraint" ]]; then
    python_constraint="$(python3 - "$pyproject_file" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as pyproject:
    requires_python = tomllib.load(pyproject).get("project", {}).get("requires-python", "")
print(requires_python)
PY
)"
  fi
  local python_spec="python${python_constraint}"

  export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-$HOME/.cache/mamba}"
  micromamba create --yes --prefix "$temp_dir/environment" --channel conda-forge "$python_spec" pip
  if [[ -s "$temp_dir/requirements.txt" ]]; then
    micromamba run --prefix "$temp_dir/environment" python -m pip install \
      --disable-pip-version-check -r "$temp_dir/requirements.txt"
  fi
  micromamba env export --prefix "$temp_dir/environment" --no-builds \
    | sed -E "s|^name:.*$|name: $project_name|; /^prefix:[[:space:]]/d" \
      > "$temp_dir/environment.yml"
  cp "$temp_dir/environment.yml" "$environment_file"
)

sync_micromamba_project() (
  local python_version temp_dir temp_requirements
  export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-$HOME/.cache/mamba}"

  if [[ ! -f "$environment_file" ]]; then
    require_requirements_for_bootstrap
    initialize_micromamba_manifest
  fi

  if [[ -f "$repo_root/.venv/conda-meta/history" ]]; then
    micromamba env update --yes --prefix "$repo_root/.venv" --file "$environment_file" --prune
  elif [[ -e "$repo_root/.venv" ]]; then
    printf 'Cannot use %s: it exists but is not a micromamba environment\n' "$repo_root/.venv" >&2
    return 1
  else
    micromamba create --yes --prefix "$repo_root/.venv" --file "$environment_file"
  fi

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT
  python_version="$(micromamba run --prefix "$repo_root/.venv" python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
  local uv_init_args=(init --bare --name "$project_name" --python "$python_version")
  uv "${uv_init_args[@]}" "$temp_dir/project"

  temp_requirements="$temp_dir/requirements.txt"
  micromamba run --prefix "$repo_root/.venv" python -m pip freeze \
    | sed -E '/^(pip|setuptools|wheel)==/d' > "$temp_requirements"
  if [[ -s "$temp_requirements" ]]; then
    uv add --project "$temp_dir/project" --no-sync --requirements "$temp_requirements"
  fi
  cp "$temp_dir/project/pyproject.toml" "$pyproject_file"
)

sync_project() {
  local manager
  manager="$(load_dependency_manager)"
  printf 'Using %s for %s\n' "$manager" "$repo_root"

  if [[ "$manager" == "uv" ]]; then
    sync_uv_project
  else
    sync_micromamba_project
  fi
}

input_hash() {
  local manager
  manager="$(load_dependency_manager)"
  {
    printf '%s\n' "$manager"
    [[ ! -f "$env_file" ]] || sha256sum "$env_file"
    if [[ "$manager" == "uv" ]]; then
      if [[ -f "$pyproject_file" ]]; then
        sha256sum "$pyproject_file"
      elif [[ -f "$requirements_file" ]]; then
        sha256sum "$requirements_file"
      fi
    else
      if [[ -f "$environment_file" ]]; then
        sha256sum "$environment_file"
      elif [[ -f "$requirements_file" ]]; then
        sha256sum "$requirements_file"
      fi
    fi
  } | sha256sum | awk '{print $1}'
}

if [[ "${1:-}" == "--once" ]]; then
  sync_project
  exit
fi

if [[ "${1:-}" == "--watch-loop" ]]; then
  exec 9>"$lock_file"
  flock -n 9 || exit 0

  last_hash="$(input_hash)"
  while true; do
    sleep 2
    current_hash="$(input_hash)"
    if [[ "$current_hash" != "$last_hash" ]]; then
      if sync_project; then
        last_hash="$(input_hash)"
      else
        printf 'Dependency synchronization failed at %s\n' "$(date -Is)" >> "$watcher_log"
        last_hash="$current_hash"
      fi
    fi
  done
fi

sync_project
nohup bash "$script_path" --watch-loop >"$watcher_log" 2>&1 </dev/null &
