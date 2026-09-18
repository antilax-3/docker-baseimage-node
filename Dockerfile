FROM antilax3/alpine:latest

# set version label
ARG build_date
ARG version
LABEL build_date="${build_date}"
LABEL version="${version}"
LABEL maintainer="Nightah"

# set versions for node and yarn
# renovate: datasource=node-version depName=node
ARG NODE_VERSION="24.3.0"
# renovate: datasource=github-releases depName=yarnpkg/yarn
ARG YARN_VERSION="1.22.22"

RUN \
echo "**** install runtime packages ****" && \
apk add --no-cache \
    libstdc++ \
    libcap && \
echo "**** install build packages ****" && \
apk add --no-cache --virtual=build-dependencies \
    curl && \
# the sha256 of this release's musl tarball, published alongside it; unset when the release has no musl
# build, which falls through to the source build below
CHECKSUM=$(curl -fsSL --compressed "https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/SHASUMS256.txt" | grep " node-v$NODE_VERSION-linux-x64-musl.tar.xz\$" | cut -d" " -f1) && \
if [ -n "${CHECKSUM}" ]; then \
    set -eu; \
    curl -fsSLO --compressed "https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64-musl.tar.xz"; \
    echo "$CHECKSUM  node-v$NODE_VERSION-linux-x64-musl.tar.xz" | sha256sum -c - \
      && tar -xJf "node-v$NODE_VERSION-linux-x64-musl.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
      && ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
else \
echo "**** Building from source ****" && \
apk add --no-cache --virtual=build-dependencies-full \
    binutils-gold \
    g++ \
    gcc \
    gnupg \
    libgcc \
    linux-headers \
    make \
    python && \
echo "**** build node ****" && \
for key in \
    C0D6248439F1D5604AAFFB4021D900FFDB233756 \
    DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 \
    CC68F5A3106FF448322E48ED27F5E38D5B0A215F \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    A363A499291CBBC940DD62E41F10027AF002F8B0 \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
; do \
    gpg --batch --keyserver keys.openpgp.org --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
done && \
curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" && \
curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" && \
gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc && \
grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - && \
tar -xf "node-v$NODE_VERSION.tar.xz" && \
cd "node-v$NODE_VERSION" && \
./configure && \
make -j"$(getconf _NPROCESSORS_ONLN)" && \
make install && \
apk del --purge \
    build-dependencies-full && \
cd ..; \
fi && \
apk add --no-cache --virtual=build-dependencies-yarn \
    gnupg \
    tar && \
echo "**** build yarn ****" && \
gpg --batch --keyserver keys.openpgp.org --recv-keys "6A010C5166006599AA17F08146C2130DFD2497F5" || \
gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "6A010C5166006599AA17F08146C2130DFD2497F5" && \
curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" && \
curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" && \
gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz && \
mkdir -p /opt && \
tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ && \
ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn && \
ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg && \
setcap cap_net_bind_service=+ep "$(which node)" && \
echo "**** cleanup ****" && \
apk del --purge \
    build-dependencies build-dependencies-yarn && \
rm -rf \
    node-v$NODE_VERSION* \
    yarn-v$YARN_VERSION* \
    SHASUMS256.txt* \
    /tmp/*

ENTRYPOINT ["/init"]
