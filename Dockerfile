# syntax=docker/dockerfile:1
ARG BASE_IMAGE="antilax3/wolfi:latest"
FROM ${BASE_IMAGE}

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
YARN_RELEASE="https://yarnpkg.com/downloads/${YARN_VERSION}"
YARN_TARBALL="yarn-v${YARN_VERSION}.tar.gz"

# The keys node currently signs its releases with, as carried by nodejs/docker-node. The full roster in
# nodejs/node's readme also lists retired releasers, which nothing published today is signed by.
NODE_KEYS="
108F52B48DB57BB0CC439B2997B01419BD92F80A
5BE8A3F6C8A5C01D106C0AD820B1A390B168D356
655F3B5C1FB3FA8D1A0CA6BDE4A7D232B936D2FD
890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4
A363A499291CBBC940DD62E41F10027AF002F8B0
C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C
CC68F5A3106FF448322E48ED27F5E38D5B0A215F
DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7
"

# Imports one key from the first keyserver that returns a usable copy. keys.openpgp.org serves keys with their user
# IDs stripped until the address is verified, and gnupg skips a key with no user ID while still exiting zero, so a
# keyserver has only worked once the key is listed.
recv_key() {
  local key="${1}" keyserver

  for keyserver in keys.openpgp.org keyserver.ubuntu.com; do
    gpg --batch --keyserver "${keyserver}" --recv-keys "${key}" || true
    if gpg --batch --list-keys "${key}" > /dev/null 2>&1; then
      return 0
    fi
  done

  return 1
}

# node names its builds by its own architecture names, not the distribution's
case "$(apk --print-arch)" in
  x86_64) NODE_ARCH="x64" ;;
  aarch64) NODE_ARCH="arm64" ;;
  *) echo "no node build is published for $(apk --print-arch)" >&2; exit 1 ;;
esac

# The image is built on both a musl and a glibc base. nodejs.org publishes binaries for glibc only, so the musl
# build comes from unofficial-builds, which names its tarballs with a -musl suffix. The two bases also package
# things differently: alpine ships setcap in libcap and gnupg under that name, and needs gnu tar and xz to unpack
# the tarball; wolfi ships setcap in libcap-utils, calls the gnupg package gpg and splits its keyserver client into
# gnupg-dirmngr, and its busybox unpacks xz itself with no tar package to install.
if ls /lib/ld-musl-* > /dev/null 2>&1; then
  NODE_RELEASE="https://unofficial-builds.nodejs.org/download/release/v${NODE_VERSION}"
  NODE_TARBALL="node-v${NODE_VERSION}-linux-${NODE_ARCH}-musl.tar.xz"
  NODE_SIGNED="false"
  RUNTIME_PACKAGES="libcap libstdc++"
  BUILD_PACKAGES="curl gnupg tar xz"
else
  NODE_RELEASE="https://nodejs.org/dist/v${NODE_VERSION}"
  NODE_TARBALL="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
  NODE_SIGNED="true"
  RUNTIME_PACKAGES="libcap-utils libstdc++"
  BUILD_PACKAGES="curl gnupg-dirmngr gpg"
fi

echo "**** install runtime packages ****"
# shellcheck disable=SC2086 # the package lists are deliberately word split.
apk add --no-cache ${RUNTIME_PACKAGES}

echo "**** install build packages ****"
# shellcheck disable=SC2086 # as above.
apk add --no-cache --virtual=build-dependencies ${BUILD_PACKAGES}

GNUPGHOME="$(mktemp -d)"
export GNUPGHOME

echo "**** install node ****"
if [ "${NODE_SIGNED}" = "true" ]; then
  # nodejs.org signs its checksums, so the manifest is verified before anything is checked against it. Importing a
  # key is best effort: one no keyserver returns only matters if it signed this release, and the verification below
  # fails in that case anyway.
  curl -fsSL --compressed -o SHASUMS256.txt.asc "${NODE_RELEASE}/SHASUMS256.txt.asc"
  for NODE_KEY in ${NODE_KEYS}; do
    recv_key "${NODE_KEY}" || echo "no keyserver returned node release key ${NODE_KEY}" >&2
  done
  gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc
else
  # unofficial-builds publishes no signature beside its checksums, so the manifest is trusted over https alone.
  curl -fsSL --compressed -o SHASUMS256.txt "${NODE_RELEASE}/SHASUMS256.txt"
fi
if ! grep -q " ${NODE_TARBALL}$" SHASUMS256.txt; then
  echo "node v${NODE_VERSION} publishes no ${NODE_TARBALL}" >&2
  exit 1
fi
curl -fsSLO --compressed "${NODE_RELEASE}/${NODE_TARBALL}"
grep " ${NODE_TARBALL}$" SHASUMS256.txt | sha256sum -c -
tar -xJf "${NODE_TARBALL}" -C /usr/local --strip-components=1 --no-same-owner
ln -s /usr/local/bin/node /usr/local/bin/nodejs
setcap cap_net_bind_service=+ep /usr/local/bin/node

echo "**** install yarn ****"
if ! recv_key "${YARN_KEY}"; then
  echo "no keyserver returned a usable copy of the yarn signing key ${YARN_KEY}" >&2
  exit 1
fi
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
  SHASUMS256.txt.asc \
  /tmp/*
EOF

ENTRYPOINT ["/init"]
