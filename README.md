# my python project template

<!-- BEGIN BADGE INJECTION -->

[![github](https://img.shields.io/badge/github-fufurobot%2Fmypython--template-181717?logo=github&logoColor=white)](https://github.com/fufurobot/mypython-template) [![branch](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2Ffufurobot%2Fmypython-template&query=%24.default_branch&label=branch&color=181717&logo=github&logoColor=white)](https://github.com/fufurobot/mypython-template) [![release](https://img.shields.io/github/v/release/fufurobot/mypython-template?sort=semver&display_name=tag&logo=github)](https://github.com/fufurobot/mypython-template/releases/latest) [![python](https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffufurobot%2Fmypython-template%2Fmain%2F.python-version&search=%5E%28.%2B%29%24&label=python&color=3776AB&replace=%241&logo=python&logoColor=white)](https://www.python.org/downloads/) [![managers](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffufurobot%2Fmypython-template%2Fmain%2F.github%2Fworkflows%2Fdevcontainer.yml&query=%24.jobs.scripts.strategy.matrix.manager%5B%2A%5D&label=managers&color=dea584)](https://github.com/fufurobot/mypython-template) [![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/fufurobot/mypython-template/main) [![codespaces](https://img.shields.io/badge/codespaces-open-181717?logo=github&logoColor=white)](https://codespaces.new/fufurobot/mypython-template?quickstart=1) [![ci](https://img.shields.io/github/actions/workflow/status/fufurobot/mypython-template/devcontainer.yml?branch=main&logo=githubactions&logoColor=white)](https://github.com/fufurobot/mypython-template/actions/workflows/devcontainer.yml) [![license](https://img.shields.io/github/license/fufurobot/mypython-template?logo=gnu&color=blue)](https://github.com/fufurobot/mypython-template/blob/main/LICENSE) [![last commit](https://img.shields.io/github/last-commit/fufurobot/mypython-template?branch=main)](https://github.com/fufurobot/mypython-template/commits/main) [![dev dependencies](https://img.shields.io/badge/dev_dependencies-1-blue)](requirements-dev.txt)

<!-- END BADGE INJECTION -->

# features

- compatible with uv, pdm, and micromamba
- auto devcontainer that show respect to python version
- set `DEPENDENCY_MANAGER=uv`, `DEPENDENCY_MANAGER=pdm`, or `DEPENDENCY_MANAGER=micromamba` in `.env` to select the project dependency manager. If unset, projects with a root `notebooks/` directory use micromamba and other projects use uv.
- bun is installed to execute npm tools by bunx
- the selected manager syncs its root manifest directly into `.venv`; if that manifest is missing, it is initialized from `requirements.txt`. The other manager's manifest is generated through a temporary project.

# requirements

`requirements.txt` lists the dependencies. Its first line may set the Python
version with `python-must`:

```text
python-must >= 3.10
numpy
# tools
ruff
black
```

A comment that holds nothing but a name opens a dependency group, and every
requirement after it belongs to that group: `numpy` above is a project
dependency, while `ruff` and `black` are in the `tools` group. Other comments
and blank lines are ignored. Each group is installed by the manager itself,
as a uv dependency group or as a pip install into the micromamba environment.

`requirements-dev.txt` is optional, is a plain list without groups, and is
installed as development dependencies: `jupyterlab` lives there, because it is
not needed to run the project.

# generated manifests

`pyproject.toml` and `environment.yml` are generated from the name of the
project root, so this template does not commit them. Each project gets its own,
and neither is ignored, so they can be committed or edited by hand per project.

# badges

Everything between these two markers is generated, so the badges follow the
project instead of a hardcoded repository:

```text
<!-- BEGIN BADGE INJECTION -->
<!-- END BADGE INJECTION -->
```

The injector reads the `origin` remote, the current branch, `python-must`,
`DEPENDENCY_MANAGER`, `LICENSE`, `.github/workflows/`, and the requirements
files, then writes the repository, Python, manager, Codespaces, Binder, CI,
license, and dependency badges. Leave the markers in place: without both of
them the README is left alone, and everything outside them is preserved.

# Binder

`binder/environment.yml` configures [Binder](https://mybinder.org): repo2docker
builds the project with its Miniconda image. It is a symlink to the generated
root `environment.yml`, so the environment is defined once.

The symlink is expected to dangle in a fresh clone: the root `environment.yml`
is generated per project and is not committed. The dependency watcher creates
the link once the root file exists, replaces a link that points elsewhere, and
leaves a regular file alone, since that one may hold hand edits.

Because the environment comes from the generated file, its Python version is
the one derived from `python-must`, so keep that line on a version repo2docker
ships a lock file for.

A Binder workspace is recognised by the `BINDER_*` variables that Binder sets.
In one, the dependency manager is always micromamba: a root `notebooks/`
directory is created so that the default resolution agrees, and the
requirements are installed into the conda environment that Binder already
built, instead of into a project `.venv`. `DEPENDENCY_MANAGER` cannot override
this, because uv cannot manage a conda environment.

Note that `notebooks/` is tracked once created, so a Binder visit can leave an
untracked directory behind in a checkout.

# tokens

`.env` also holds `GITHUB_TOKEN`, a personal access token with which the
scripts can manage the remote CI configuration. `git` ignores `.env`, and
`.env.example` carries a placeholder instead of a real token, so copy that file
and fill in the value:

```bash
cp .env.example .env
chmod 600 .env
```

# continuous integration

`.github/workflows/devcontainer.yml` runs `post-install.sh` and a one-shot
synchronization on a GitHub runner for each dependency manager, then checks the
generated manifest and badges. Use it instead of running the scripts locally
when the network is unreliable: `gh workflow run devcontainer.yml`, or push
under `.devcontainer/`, `binder/`, or `requirements*.txt`.

# publishing

The template is not a Python package: it describes an environment through
`requirements.txt`. To publish one anyway, `.devcontainer/build-package.sh`
generates a package in a scratch directory with `uv init --package`, which
writes a `pyproject.toml` and a `src` layout, and adds both requirements files
as its development dependencies, so the package and the environment cannot
drift apart. `python-must` and the `# <name>` group headers are dropped on the
way, since neither is a package.

```bash
bash .devcontainer/build-package.sh "$TMPDIR/mypython-template" fufurobot/mypython-template
# artifacts in $TMPDIR/mypython-template/dist
```

`.github/workflows/release.yml` runs that script and publishes to TestPyPI
through a [Trusted Publisher](https://docs.pypi.org/trusted-publishers/): the
workflow asks GitHub for an OIDC token, so no API token or password is stored.
The pending publisher on TestPyPI has to name, exactly:

| Field | Value |
| --- | --- |
| Project | `mypython-template-fufurobot` |
| Owner | `fufurobot` |
| Repository | `mypython-template` |
| Workflow | `release.yml` |
| Environment | `testpypi` |

Publishing happens on a `v*` tag or by running the workflow by hand:

```bash
git tag v0.1.0 && git push origin v0.1.0
gh workflow run release.yml
```

TestPyPI refuses a version that already exists, so every publish needs a new
one. A tag only triggers the workflow: it does not set the version. The version
is whatever `uv init` wrote into the generated `pyproject.toml`, so bumping it
between publishes is what makes each run uploadable.

## attestations

The publish step runs with `attestations: false`. Publish API attestations are
signed through [Sigstore](https://www.sigstore.dev/)'s transparency log, Rekor,
and Rekor answered `502 Bad Gateway` to this repository's runners while being
healthy elsewhere, which failed the publish before any upload started. Nothing
about publishing to TestPyPI depends on them. Re-enable attestations, by
dropping that line, when publishing to PyPI proper, and check that the failure
is gone first:

```text
sigstore._internal.rekor.RekorClientError: Rekor returned an unknown error with HTTP 502
```

The build job runs regardless, so a publish failure never loses the artifacts:
they are uploaded as the `dist` artifact of the run.
