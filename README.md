# my python project template

## Open in vscode

[![Open in Codespaces (VS Code)](https://github.com/codespaces/badge.svg)](https://codespaces.new/fufurobot/mypython-template?quickstart=1&editor=web)

## Open in JupyterLab

[![Open in Codespaces (JupyterLab)](https://github.com/codespaces/badge.svg)](https://codespaces.new/fufurobot/mypython-template?quickstart=1&editor=jupyter)

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
