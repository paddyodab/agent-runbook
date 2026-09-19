# template/Dockerfile — omp agent template for Docker Sandboxes
#
# By-the-book per https://docs.docker.com/ai/sandboxes/customize/templates/:
# extend a built-in base variant, keep the non-root `agent` user (UID 1000) for
# user-level tools, run root only for system packages.
#
# Base: shell-docker — no built-in agent, Docker Engine inside the sandbox,
# non-root `agent` user with passwordless sudo, HTTP(S)_PROXY env preserved
# across sudo, /etc/sandbox-persistent.sh sourced before every bash invocation.
#
# Baked into the image (the slow-to-install layer, per the docs' split):
#   - mise (version manager shim dir on PATH)
#   - omp pinned to OMP_VERSION build arg
#   - gh (gh-issues adapter dep)
#   - glow (herdr mind-pane rendering, optional dep in machine.yml)
#
# Build:
#   docker build --build-arg OMP_VERSION=18.2.0 -t paddyodab/sbx-omp:18.2.0 --push template/
#
# Kit contract: kit/omp/spec.yaml points sandbox.image at this template.

FROM docker/sandbox-templates:shell-docker

ARG OMP_VERSION=18.2.0
ENV OMP_VERSION=${OMP_VERSION}

# System-level packages as root.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        gh \
        glow \
    && rm -rf /var/lib/apt/lists/*

# User-level tooling as agent (lands under /home/agent, per the docs' warning:
# rustup/nvm/mise-class tools installed as root end up in /root and are lost).
USER agent
RUN mkdir -p /home/agent/.local/bin \
    && curl -fsSL "https://mise.run" -o /tmp/mise-install.sh \
    && bash /tmp/mise-install.sh \
    && rm -f /tmp/mise-install.sh \
    && /home/agent/.local/bin/mise use -g --yes "github:can1357/oh-my-pi@${OMP_VERSION}" \
    && /home/agent/.local/bin/mise reshim

# mise shims on PATH for every shell (persistent env file is sourced before
# every bash invocation in the sandbox, per kit-examples docs).
RUN echo 'export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"' >> /etc/sandbox-persistent.sh
ENV PATH="/home/agent/.local/share/mise/shims:/home/agent/.local/bin:${PATH}"

# Verify the pin inside the image build itself (fail the build, not the sandbox).
RUN omp --version | grep -q "omp/${OMP_VERSION}" \
    || { echo "REFUSED: omp version mismatch, wanted ${OMP_VERSION}, got: $(omp --version)"; exit 1; }
RUN gh --version >/dev/null && glow --version >/dev/null && jq --version >/dev/null

USER agent
WORKDIR /home/agent/workspace