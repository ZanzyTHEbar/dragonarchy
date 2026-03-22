ARG BASE_IMAGE=debian:bookworm-slim

FROM rust:1-bookworm AS pkgsolve-builder
WORKDIR /work
COPY tools/pkgsolve /work/tools/pkgsolve
RUN cargo build --manifest-path /work/tools/pkgsolve/Cargo.toml --release

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
COPY --from=pkgsolve-builder /work/tools/pkgsolve/target/release/pkgsolve /usr/local/bin/pkgsolve

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

RUN test -f .artifacts/pkgsolve/debian/headless-minimal/resolve/plan.lock.json \
    && test -f .artifacts/pkgsolve/debian/headless-minimal/verify/plan.lock.json \
    && jq -e '.status == "satisfiable" or .status == "partially_satisfiable"' \
        .artifacts/pkgsolve/debian/headless-minimal/verify/plan.lock.json >/dev/null

RUN bash -lc 'scripts/install/validate.sh --host headless --json | tee /tmp/validate.json' \
    && jq -e '.failed == 0' /tmp/validate.json >/dev/null
