[Dockerfile](https://github.com/AntilaX-3/docker-baseimage-node/blob/master/Dockerfile)

[![](https://images.microbadger.com/badges/image/antilax3/node.svg)](https://microbadger.com/images/antilax3/node "Get your own image badge on microbadger.com")

### This base container is not aimed at public consumption. It exists to serve as a single endpoint for AntilaX-3 containers and is based upon [Alpine Linux](https://hub.docker.com/_/alpine/) and [S6 overlay](https://github.com/just-containers/s6-overlay).

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

`NODE_VERSION` and `YARN_VERSION` are managed by renovate. The sha256 of node's musl tarball is read from the
`SHASUMS256.txt` that [unofficial-builds.nodejs.org](https://unofficial-builds.nodejs.org) publishes beside it, so a
version bump needs no other change. A release with no musl build leaves the checksum unset and falls through to
building node from source, where the checksum comes from the gpg signed manifest on nodejs.org.

The release keys used by that fallback are kept in step with
[nodejs/docker-node](https://github.com/nodejs/docker-node), which this Dockerfile is derived from.
