# The devcontainer as a standalone image.
#
# The image starts from the same base that devcontainer.json uses, then runs
# post-install.sh so that uv, pdm, micromamba and bun are already present. A
# codespace built from this image therefore skips their download, and the image
# itself can be pulled where the installers cannot reach the network.
#
# Build:
#   docker build -f .devcontainer/Dockerfile -t mypython-template .
# The release workflow builds it for linux/amd64 and pushes it to the GitHub
# Container Registry.

FROM ghcr.io/bartventer/devcontainer-images/base-archlinux:latest

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The installers need these, and the base image keeps them out of the non-root
# user's reach.
RUN pacman -Sy --noconfirm --needed curl tar bzip2 \
 && pacman -Scc --noconfirm

# post-install.sh resolves $HOME, so it runs as the devcontainer user, with the
# same PATH that devcontainer.json gives the container.
COPY --chown=vscode:vscode .devcontainer/post-install.sh /tmp/post-install.sh
RUN install -d -o vscode -g vscode /home/vscode/.local/bin \
 && su vscode -s /bin/bash -c \
    'PATH="/home/vscode/.local/bin:$PATH" bash /tmp/post-install.sh' \
 && rm -f /tmp/post-install.sh

# Fail the build rather than ship an image whose tools do not run.
RUN su vscode -s /bin/bash -c \
    'for tool in uv pdm micromamba bun; do \
       command -v "$tool" >/dev/null || { echo "$tool is missing" >&2; exit 1; }; \
     done'

ENV PATH="/home/vscode/.local/bin:${PATH}"
USER vscode
WORKDIR /workspaces

# Keep the default command of the base image, which the devcontainer spec
# replaces anyway.
LABEL org.opencontainers.image.title="mypython-template" \
      org.opencontainers.image.description="Python project template: uv, pdm, and micromamba" \
      org.opencontainers.image.source="https://github.com/fufurobot/mypython-template" \
      org.opencontainers.image.licenses="AGPL-3.0"
