#!/usr/bin/env bash
set -euo pipefail

script_path="$(realpath "${BASH_SOURCE[0]}")"
repo_root="$(dirname "$(dirname "$script_path")")"
readme_file="$repo_root/README.md"
badge_begin='<!-- BEGIN BADGE INJECTION -->'
badge_end='<!-- END BADGE INJECTION -->'

# inject_badges: rewrites the block between the badge markers of README.md from
# what the repository says about itself. A README without both markers is left
# alone, so the markers have to be added once by hand.
inject_badges() {
  if [[ ! -f "$readme_file" ]]; then
    return 0
  fi
  # The markers may also be quoted elsewhere in the README, so the pair to fill
  # is the first one, and a marker must be alone on its line to count.
  if [[ "$(grep -c -x -F "$badge_begin" "$readme_file" || true)" == "0" ]] \
    || [[ "$(grep -c -x -F "$badge_end" "$readme_file" || true)" == "0" ]]; then
    printf 'Skipping badges: %s needs a %s and a %s line\n' \
      "$readme_file" "$badge_begin" "$badge_end" >&2
    return 0
  fi

  python3 - "$repo_root" "$readme_file" "$badge_begin" "$badge_end" <<'PY'
import os
import re
import subprocess
import sys
import urllib.parse

root, readme_path, begin, end = sys.argv[1:]


def git(*args):
    try:
        result = subprocess.run(
            ("git",) + args, cwd=root, capture_output=True, text=True, check=False
        )
    except OSError:
        return ""
    return result.stdout.strip() if result.returncode == 0 else ""


def read(name):
    path = os.path.join(root, name)
    if not os.path.isfile(path):
        return ""
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def shields(label, message, color, link, logo=""):
    """A shields.io badge that links to link.

    shields.io wants `--` for a literal dash and `_` for a space; operators and
    other punctuation are URL-encoded.
    """
    def escape(text):
        text = urllib.parse.quote(str(text).replace("-", "--").replace(" ", "_"), safe="._")
        return text

    image = f"https://img.shields.io/badge/{escape(label)}-{escape(message)}-{color}"
    if logo:
        image += f"?logo={logo}&logoColor=white"
    return f"[![{label}]({image})]({link})"


# Repository identity, read the way Codespaces and Binder read it.
owner = repository = ""
match = re.search(
    r"github\.com[:/]+([^/]+)/([^/\s]+?)(?:\.git)?$",
    git("config", "--get", "remote.origin.url"),
)
if match:
    owner, repository = match.group(1), match.group(2)
# A detached HEAD or a fresh checkout reports no branch, so fall back to the
# branch that the remote repository uses.
branch = git("symbolic-ref", "--short", "-q", "HEAD")
if not branch:
    branch = "main"

# Facts about the project, from the files this template maintains.
requirements = read("requirements.txt")
python_constraint = ""
for line in requirements.splitlines():
    fields = line.split()
    if fields and fields[0].lower() == "python-must":
        python_constraint = "".join(fields[1:])
        break

manager = ""
for line in read(".env").splitlines():
    match = re.match(r"\s*(?:export\s+)?DEPENDENCY_MANAGER\s*=\s*(.*)", line)
    if match:
        value = match.group(1).split("#")[0].strip().strip("'\"")
        if value:
            manager = value.lower()
if not manager:
    manager = "micromamba" if os.path.isdir(os.path.join(root, "notebooks")) else "uv"

license_text = read("LICENSE")
licenses = [
    ("GNU AFFERO GENERAL PUBLIC LICENSE", "AGPL-3.0"),
    ("GNU LESSER GENERAL PUBLIC LICENSE", "LGPL-3.0"),
    ("GNU GENERAL PUBLIC LICENSE", "GPL-3.0"),
    ("Apache License", "Apache-2.0"),
    ("MIT License", "MIT"),
    ("BSD 3-Clause", "BSD-3-Clause"),
]
license_name = next((name for marker, name in licenses if marker in license_text), "")


def count_requirements(text):
    return len([
        line for line in text.splitlines()
        if line.strip()
        and not line.lstrip().startswith("#")
        and not line.lower().startswith("python-must")
    ])


badges = []

if owner and repository:
    badges.append(
        shields("github", f"{owner}/{repository}", "181717",
                f"https://github.com/{owner}/{repository}", "github")
    )

if python_constraint:
    # ">=3.10" reads best as the minimum version, "3.10, 3.11" as the set.
    python_message = re.sub(r"^[\^~=]+", "", python_constraint) or python_constraint
    if python_message.startswith(">"):
        python_message = ">=" + python_message.lstrip(">=").lstrip("=")
    badges.append(
        shields("python", python_message, "3776AB",
                "https://www.python.org/downloads/", "python")
    )

if manager == "uv":
    badges.append(shields("manager", "uv", "dea584", "https://docs.astral.sh/uv/", "uv"))
elif manager == "pdm":
    badges.append(shields("manager", "pdm", "9575cd", "https://pdm-project.org/", "pdm"))
elif manager == "micromamba":
    badges.append(
        shields("manager", "micromamba", "6db33f", "https://mamba.readthedocs.io/")
    )

# Binder builds an environment from the repository, so it needs a repository
# that mybinder.org can clone, not just a checkout.
if owner and repository:
    badges.append(
        "[![Binder](https://mybinder.org/badge_logo.svg)]"
        f"(https://mybinder.org/v2/gh/{owner}/{repository}/{branch})"
    )
    badges.append(
        shields("codespaces", "open", "181717",
                f"https://codespaces.new/{owner}/{repository}?quickstart=1", "github")
    )

workflows = os.path.join(root, ".github", "workflows")
if os.path.isdir(workflows):
    for name in sorted(os.listdir(workflows)):
        if name.endswith((".yml", ".yaml")):
            workflow = name.rsplit(".", 1)[0]
            badges.append(
                shields("ci", "passing", "2088FF",
                        f"https://github.com/{owner}/{repository}/actions/workflows/{name}",
                        "githubactions")
            )

if license_name:
    badges.append(shields("license", license_name, "blue", "LICENSE"))

main_count = count_requirements(requirements)
dev_count = count_requirements(read("requirements-dev.txt"))
if main_count:
    badges.append(shields("dependencies", str(main_count), "blue", "requirements.txt"))
if dev_count:
    badges.append(
        shields("dev dependencies", str(dev_count), "blue", "requirements-dev.txt")
    )

with open(readme_path, encoding="utf-8") as handle:
    readme = handle.read()

block = "\n".join([begin, "", " ".join(badges), "", end]) + "\n"
updated = re.sub(
    re.escape(begin) + r".*?" + re.escape(end) + r"\n?",
    lambda _: block,
    readme,
    count=1,
    flags=re.DOTALL,
)
if updated != readme:
    with open(readme_path, "w", encoding="utf-8") as handle:
        handle.write(updated)
    print(f"README badges updated ({len(badges)})")
PY
}

inject_badges
