# my python project template

<!-- BEGIN BADGE INJECTION -->

[![github](https://img.shields.io/badge/github-fufurobot%2Fmypython--template-181717?logo=github&logoColor=white)](https://github.com/fufurobot/mypython-template) [![python](https://img.shields.io/badge/python-%3E%3D3.10-3776AB?logo=python&logoColor=white)](https://www.python.org/downloads/) [![manager](https://img.shields.io/badge/manager-uv-dea584?logo=uv&logoColor=white)](https://docs.astral.sh/uv/) [![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/fufurobot/mypython-template/main) [![codespaces](https://img.shields.io/badge/codespaces-open-181717?logo=github&logoColor=white)](https://codespaces.new/fufurobot/mypython-template?quickstart=1) [![license](https://img.shields.io/badge/license-AGPL--3.0-blue)](LICENSE) [![dev dependencies](https://img.shields.io/badge/dev_dependencies-1-blue)](requirements-dev.txt)

<!-- END BADGE INJECTION -->

# features

- compatible with both uv and micromamba
- auto devcontainer that show respect to python version
- set `DEPENDENCY_MANAGER=uv` or `DEPENDENCY_MANAGER=micromamba` in `.env` to select the project dependency manager. If unset, projects with a root `notebooks/` directory use micromamba and other projects use uv.
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

