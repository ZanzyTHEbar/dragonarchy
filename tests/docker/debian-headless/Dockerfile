ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color

RUN apt-get update && apt-get install -y \
    bash \
    ca-certificates \
    curl \
    file \
    findutils \
    git \
    gnupg \
    locales \
    procps \
    sudo \
    tar \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash dragon \
    && echo 'dragon ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/dragon \
    && chmod 0440 /etc/sudoers.d/dragon

USER dragon
WORKDIR /home/dragon/dotfiles

COPY --chown=dragon:dragon . /home/dragon/dotfiles

RUN ./install.sh \
    --host headless \
    --headless \
    --bundle minimal \
    --no-secrets \
    --no-first-run \
    --no-system-config

RUN ./install.sh \
    --host headless \
    --headless \
    --bundle minimal \
    --no-secrets \
    --no-first-run \
    --no-system-config

RUN git config --global user.name "CI Smoke" \
    && git config --global user.email "ci@example.com"

RUN ./scripts/install/first-run.sh --dry-run --headless

RUN bash -lc 'scripts/install/validate.sh --host headless --json | tee /tmp/validate.json' \
    && jq -e '.failed == 0' /tmp/validate.json >/dev/null
