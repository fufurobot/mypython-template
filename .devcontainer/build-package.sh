#!/usr/bin/env bash
set -euo pipefail

# Builds the project as a distributable package.
#
#   build-package.sh WORKDIR [OWNER/REPOSITORY]
#
# The template describes an environment through requirements.txt, so it has no
# package of its own. A package is generated in WORKDIR with `uv init
# --package`, which writes a pyproject.toml and a src layout, and the
# requirements become its development dependencies, so the two do not drift
# apart. The artifacts are left in WORKDIR/dist.

workdir="${1:?usage: build-package.sh WORKDIR [OWNER/REPOSITORY]}"
repository="${2:-}"
package_name="${PACKAGE_NAME:-mypython-template-fufurobot}"
project_dir="$workdir/project"

repo_root="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
requirements_file="$repo_root/requirements.txt"
dev_requirements_file="$repo_root/requirements-dev.txt"

# Build for the Python version the project declares.
python_version=""
if [[ -f "$requirements_file" ]]; then
  python_version="$(awk 'tolower($1) == "python-must" { $1 = ""; print; exit }' "$requirements_file" \
    | sed -E 's/[[:space:]]//g; s/^[<>=!~^]+//; s/,.*//')"
fi

rm -rf "$project_dir"
mkdir -p "$project_dir"
uv init --package ${python_version:+--python "$python_version"} \
  --name "$package_name" "$project_dir"

# The requirements are read, never modified. They also carry things that are
# not packages: python-must, which is a directive of this template, and the
# `# <name>` group headers, which document groups for the watcher.
plain_requirements() {
  if [[ ! -f "$1" ]]; then
    return 0
  fi
  sed -E '/^[[:space:]]*(#|$)/d' "$1" \
    | sed -E '/^[[:space:]]*python-must([[:space:]]|<|>|=|!|~|$)/Id'
}

main_requirements="$workdir/main-requirements.txt"
dev_requirements="$workdir/dev-requirements.txt"
plain_requirements "$requirements_file" > "$main_requirements"
plain_requirements "$dev_requirements_file" > "$dev_requirements"

if [[ -s "$main_requirements" ]]; then
  uv add --project "$project_dir" --dev --requirements "$main_requirements"
fi
if [[ -s "$dev_requirements" ]]; then
  uv add --project "$project_dir" --dev --requirements "$dev_requirements"
fi

if [[ -n "$repository" ]]; then
  python3 - "$project_dir/pyproject.toml" "$repository" <<'PY'
import sys
import tomllib

path, repository = sys.argv[1:]
with open(path, "rb") as handle:
    project = tomllib.load(handle)["project"]
if "urls" in project:
    sys.exit(0)
with open(path, "a", encoding="utf-8") as handle:
    handle.write(f'\n[project.urls]\nRepository = "https://github.com/{repository}"\n')
PY
fi

uv build --project "$project_dir" --out-dir "$workdir/dist"
