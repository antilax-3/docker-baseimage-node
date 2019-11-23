FROM antilax3/alpine

# set version label
ARG build_date
ARG version
LABEL build_date="${build_date}"
LABEL version="${version}"
LABEL maintainer="Nightah"

# set versions for node and yarn
ARG NODE_VERSION="13.2.0"
ARG YARN_VERSION="1.19.1"

RUN \
echo "**** install runtime packages ****" && \
apk add --no-cache \
    libstdc++ \
    libcap && \
echo "**** install build packages ****" && \
apk add --no-cache --virtual=build-dependencies \
    curl && \
CHECKSUM="38e6af00cb12b6fa55f204aab597ae7029b1d60a182e01b28836494caa662b8e" && \
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
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C ; \
do \
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
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
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
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
