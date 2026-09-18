# syntax=docker/dockerfile:1
FROM antilax3/alpine:latest

# set version label
ARG build_date
ARG version
LABEL build_date="${build_date}"
LABEL version="${version}"
LABEL maintainer="Nightah"

# set versions for node and yarn
# renovate: datasource=node-version depName=node
ARG NODE_VERSION="24.21.0"
# renovate: datasource=github-releases depName=yarnpkg/yarn
ARG YARN_VERSION="1.22.22"

SHELL ["/bin/ash", "-euo", "pipefail", "-c"]

RUN <<'EOF'
set -euo pipefail

# the key yarn signs its releases with, from https://yarnpkg.com/en/docs/install
YARN_KEY="6A010C5166006599AA17F08146C2130DFD2497F5"
NODE_RELEASE="https://unofficial-builds.nodejs.org/download/release/v${NODE_VERSION}"
# unofficial-builds names its musl tarballs by node's own architecture names, not alpine's
case "$(apk --print-arch)" in
  x86_64) NODE_ARCH="x64" ;;
  aarch64) NODE_ARCH="arm64" ;;
  *) echo "no musl build of node is published for $(apk --print-arch)" >&2; exit 1 ;;
esac
NODE_TARBALL="node-v${NODE_VERSION}-linux-${NODE_ARCH}-musl.tar.xz"
YARN_RELEASE="https://yarnpkg.com/downloads/${YARN_VERSION}"
YARN_TARBALL="yarn-v${YARN_VERSION}.tar.gz"

echo "**** install runtime packages ****"
apk add --no-cache \
  libcap \
  libstdc++

echo "**** install build packages ****"
apk add --no-cache --virtual=build-dependencies \
  curl \
  gnupg \
  tar \
  xz

echo "**** install node ****"
curl -fsSL --compressed -o SHASUMS256.txt "${NODE_RELEASE}/SHASUMS256.txt"
if ! grep -q " ${NODE_TARBALL}$" SHASUMS256.txt; then
  echo "node v${NODE_VERSION} publishes no linux-${NODE_ARCH}-musl build" >&2
  exit 1
fi
curl -fsSLO --compressed "${NODE_RELEASE}/${NODE_TARBALL}"
grep " ${NODE_TARBALL}$" SHASUMS256.txt | sha256sum -c -
tar -xJf "${NODE_TARBALL}" -C /usr/local --strip-components=1 --no-same-owner
ln -s /usr/local/bin/node /usr/local/bin/nodejs
setcap cap_net_bind_service=+ep /usr/local/bin/node

echo "**** install yarn ****"
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
gpg --batch --keyserver keys.openpgp.org --recv-keys "${YARN_KEY}" ||
  gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${YARN_KEY}"
curl -fsSLO --compressed "${YARN_RELEASE}/${YARN_TARBALL}"
curl -fsSLO --compressed "${YARN_RELEASE}/${YARN_TARBALL}.asc"
gpg --batch --verify "${YARN_TARBALL}.asc" "${YARN_TARBALL}"
gpgconf --kill all
mkdir -p /opt
tar -xzf "${YARN_TARBALL}" -C /opt/
ln -s "/opt/yarn-v${YARN_VERSION}/bin/yarn" /usr/local/bin/yarn
ln -s "/opt/yarn-v${YARN_VERSION}/bin/yarnpkg" /usr/local/bin/yarnpkg

echo "**** cleanup ****"
apk del --purge \
  build-dependencies
rm -rf \
  "${GNUPGHOME}" \
  "${NODE_TARBALL}" \
  "${YARN_TARBALL}" \
  "${YARN_TARBALL}.asc" \
  SHASUMS256.txt \
  /tmp/*
EOF

ENTRYPOINT ["/init"]
