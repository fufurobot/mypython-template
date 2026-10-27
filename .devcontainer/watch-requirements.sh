#!/usr/bin/env bash
set -euo pipefail

script_path="$(realpath "${BASH_SOURCE[0]}")"
repo_root="$(dirname "$(dirname "$script_path")")"
requirements_file="$repo_root/requirements.txt"
watcher_log="${TMPDIR:-/tmp}/stupidinfer-requirements-watcher.log"
lock_file="${TMPDIR:-/tmp}/stupidinfer-requirements-watcher.lock"

generate_manifests() {
  python3 - "$requirements_file" "$repo_root" <<'PY'
import json
import os
import re
import sys
import tempfile
from pathlib import Path

requirements_file = Path(sys.argv[1])
repo_root = Path(sys.argv[2])
project_name = re.sub(r"[-_.]+", "-", repo_root.name).lower()
python_constraint_re = re.compile(
    r"(?:~=|===|==|!=|<=|>=|<|>)[0-9][A-Za-z0-9.!+*_-]*"
)
python_marker_re = re.compile(r"^python-must(?=$|[\s<>=!~])\s*(.*)$", re.IGNORECASE)

dependencies = []
python_constraints = []
for raw_line in requirements_file.read_text(encoding="utf-8").splitlines():
    line = re.split(r"\s+#", raw_line, maxsplit=1)[0].strip()
    if not line or line.startswith("#"):
        continue

    match = python_marker_re.match(line)
    if match:
        constraint = re.sub(r"\s+", "", match.group(1))
        if not constraint or not re.fullmatch(
            rf"{python_constraint_re.pattern}(?:,{python_constraint_re.pattern})*",
            constraint,
        ):
            raise SystemExit(f"Invalid python-must constraint: {line}")
        python_constraints.append(constraint)
    else:
        dependencies.append(line)

python_constraint = ",".join(python_constraints)
toml_lines = [
    "[project]",
    f"name = {json.dumps(project_name)}",
    'version = "0.1.0"',
]
if python_constraint:
    toml_lines.append(f"requires-python = {json.dumps(python_constraint)}")
toml_lines.append("dependencies = [")
toml_lines.extend(f"  {json.dumps(dependency)}," for dependency in dependencies)
toml_lines.extend(["]", ""])
pyproject_content = "\n".join(toml_lines)

environment_lines = [
    f"name: {json.dumps(project_name)}",
    "channels:",
    "  - conda-forge",
    "dependencies:",
    f"  - python{python_constraint}",
    "  - pip",
]
if dependencies:
    environment_lines.append("  - pip:")
    environment_lines.extend(f"      - {json.dumps(dependency)}" for dependency in dependencies)
environment_content = "\n".join(environment_lines) + "\n"


def update_file(path, content):
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=path.parent, delete=False
    ) as temporary_file:
        temporary_file.write(content)
        temporary_path = Path(temporary_file.name)
    os.chmod(temporary_path, 0o644)
    os.replace(temporary_path, path)


update_file(repo_root / "pyproject.toml", pyproject_content)
update_file(repo_root / "environment.yml", environment_content)
PY
}

if [[ "${1:-}" == "--once" ]]; then
  generate_manifests
  exit
fi

if [[ "${1:-}" != "--watch-loop" ]]; then
  nohup bash "$script_path" --watch-loop >"$watcher_log" 2>&1 </dev/null &
  exit 0
fi

exec 9>"$lock_file"
flock -n 9 || exit 0

generate_manifests || true
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