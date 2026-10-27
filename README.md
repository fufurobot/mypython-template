# my python project template

## Open in vscode

[![Open in Codespaces (VS Code)](https://github.com/codespaces/badge.svg)](https://codespaces.new/fufurobot/mypython-template?quickstart=1&editor=web)

## Open in JupyterLab

[![Open in Codespaces (JupyterLab)](https://github.com/codespaces/badge.svg)](https://codespaces.new/fufurobot/mypython-template?quickstart=1&editor=jupyter)

# features

- compatible with both uv and micromamba
- auto devcontainer that show respect to python version
- set `DEPENDENCY_MANAGER=uv` or `DEPENDENCY_MANAGER=micromamba` in `.env` to select the project dependency manager. If unset, projects with a root `notebooks/` directory use micromamba and other projects use uv.
- the selected manager syncs its root manifest directly into `.venv`; if that manifest is missing, it is initialized from `requirements.txt`. The other manager's manifest is generated through a temporary project.
- bun is installed to execute npm tools by bunx
