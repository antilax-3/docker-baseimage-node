[Dockerfile](https://github.com/AntilaX-3/docker-baseimage-node/blob/master/Dockerfile)

[![](https://images.microbadger.com/badges/image/antilax3/node.svg)](https://microbadger.com/images/antilax3/node "Get your own image badge on microbadger.com")

### This base container is not aimed at public consumption. It exists to serve as a single endpoint for AntilaX-3 containers and is based upon [Wolfi](https://github.com/wolfi-dev) and [S6 overlay](https://github.com/just-containers/s6-overlay).

## Tags

Two variants are built from the one Dockerfile, for `linux/amd64` and `linux/arm64`.

| Variant | Base | Tags |
| --- | --- | --- |
| wolfi | [antilax3/wolfi](https://hub.docker.com/r/antilax3/wolfi) | `latest`, `24`, `24.21`, `24.21.0` |
| alpine | [antilax3/alpine](https://hub.docker.com/r/antilax3/alpine) | `alpine`, `24-alpine`, `24.21-alpine`, `24.21.0-alpine` |

Wolfi is the default because it uses glibc, which lets the image install the binaries nodejs.org publishes itself
and verify their checksum manifest against node's release signature. The alpine variant is musl and keeps taking
its node from unofficial-builds, which publishes no signature.

## Development

Linting runs locally through [lefthook](https://github.com/evilmartians/lefthook). Install the hooks once per clone:

```bash
lefthook install
```

`pre-commit` runs [editorconfig-checker](https://github.com/editorconfig-checker/editorconfig-checker),
[hadolint](https://github.com/hadolint/hadolint), `jq`, [shellcheck](https://github.com/koalaman/shellcheck),
[typos](https://github.com/crate-ci/typos) and [yamllint](https://github.com/adrienverge/yamllint) over the staged
files, and `commit-msg` enforces [Conventional Commits](https://www.conventionalcommits.org). Run everything on demand
with:

```bash
lefthook run pre-commit --all-files
```

### Bumping node

`NODE_VERSION` and `YARN_VERSION` are managed by renovate, and nothing else has to move with them. Both variants build
from the same Dockerfile, which picks its node tarball by the libc of the base image passed in `BASE_IMAGE`.

For wolfi that is the glibc build from [nodejs.org](https://nodejs.org), whose `SHASUMS256.txt.asc` is verified
against node's release keys before any checksum in it is trusted. For alpine it is the musl build from
[unofficial-builds.nodejs.org](https://unofficial-builds.nodejs.org), which publishes no signature, so its manifest
is trusted over https alone. Either way the build fails with a plain message if a release publishes no build for the
architecture being built, and yarn's tarball is verified against its release signature on both.

The node release keys are the set [nodejs/docker-node](https://github.com/nodejs/docker-node) carries, which this
Dockerfile is derived from. Importing one is best effort: a key no keyserver returns only matters if it signed the
release being built, and the verification fails in that case anyway.
