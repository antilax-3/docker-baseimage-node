<p align="center">
  <a href="https://github.com/AntilaX-3/"><img src="https://avatars.githubusercontent.com/u/35715409" width="150" title="AntilaX-3"></a>
</p>

<p align="center">
  <a href="https://buildkite.com/antilax-3/node"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/dynamic/json.svg?url=https%3A%2F%2Fimg.shields.io%2Fbuildkite%2F7ce2221af3c956af620f0b04d28943588feefe2931ad5cad7d%2Fmaster.json&query=%24.message&label=build&logo=buildkite&logoColor=%2314cc80&mode=dark&size=sm&variant=outline"><img alt="Build" src="https://shieldcn.dev/badge/dynamic/json.svg?url=https%3A%2F%2Fimg.shields.io%2Fbuildkite%2F7ce2221af3c956af620f0b04d28943588feefe2931ad5cad7d%2Fmaster.json&query=%24.message&label=build&logo=buildkite&logoColor=%2314cc80&mode=light&size=sm&variant=outline"></picture></a>
  <a href="https://hub.docker.com/r/antilax3/node/tags"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/dynamic/json.svg?url=https%3A%2F%2Fimg.shields.io%2Fdocker%2Fimage-size%2Fantilax3%2Fnode%2Flatest.json&query=%24.message&label=image%20size&logo=docker&logoColor=%232496ed&mode=dark&size=sm&variant=outline"><img alt="Docker Size" src="https://shieldcn.dev/badge/dynamic/json.svg?url=https%3A%2F%2Fimg.shields.io%2Fdocker%2Fimage-size%2Fantilax3%2Fnode%2Flatest.json&query=%24.message&label=image%20size&logo=docker&logoColor=%232496ed&mode=light&size=sm&variant=outline"></picture></a>
  <a href="https://hub.docker.com/r/antilax3/node"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/dynamic/json.svg?url=https%3A%2F%2Fimg.shields.io%2Fdocker%2Fpulls%2Fantilax3%2Fnode.json&query=%24.message&label=pulls&logo=docker&logoColor=%232496ed&mode=dark&size=sm&variant=outline"><img alt="Docker Pulls" src="https://shieldcn.dev/badge/dynamic/json.svg?url=https%3A%2F%2Fimg.shields.io%2Fdocker%2Fpulls%2Fantilax3%2Fnode.json&query=%24.message&label=pulls&logo=docker&logoColor=%232496ed&mode=light&size=sm&variant=outline"></picture></a>
</p>

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
