FROM antilax3/alpine

# set version label
ARG build_date
ARG version
LABEL build_date="${build_date}"
LABEL version="${version}"
LABEL maintainer="Nightah"

# set versions for node and yarn
ARG NODE_VERSION="19.7.0"
ARG YARN_VERSION="1.22.19"

RUN \
echo "**** install runtime packages ****" && \
apk add --no-cache \
    libstdc++ \
    libcap && \
echo "**** install build packages ****" && \
apk add --no-cache --virtual=build-dependencies \
    curl && \
CHECKSUM="a3bf3bd218fd77aa91e187ae5c77964820a35c0f58018151aa9653e2fc5b2313" && \
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
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    141F07595B7B3FFE74309A937405533BE57C7D57 \
    74F12602B6F1C4E913FAA37AD3A89613643B6201 \
    61FC681DFB92A079F1685E77973F295594EC4689 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
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
make -j$(getconf _NPROCESSORS_ONLN) && \
make install && \
apk del --purge \
    build-dependencies-full && \
cd ..; \
fi && \
apk add --no-cache --virtual=build-dependencies-yarn \
    gnupg \
    tar && \
echo "**** build yarn ****" && \
for key in \
   6A010C5166006599AA17F08146C2130DFD2497F5 ; \
do \
    gpg --batch --keyserver keys.openpgp.org --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
done && \
curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" && \
curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" && \
gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz && \
mkdir -p /opt && \
tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ && \
ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn && \
ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg && \
setcap cap_net_bind_service=+ep `which node` && \
echo "**** cleanup ****" && \
apk del --purge \
    build-dependencies build-dependencies-yarn && \
rm -rf \
    node-v$NODE_VERSION* \
    yarn-v$YARN_VERSION* \
    SHASUMS256.txt* \
    /tmp/*

ENTRYPOINT ["/init"]
