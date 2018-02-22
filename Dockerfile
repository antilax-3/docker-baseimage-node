FROM antilax3/alpine

# set version label
LABEL build_date=""
LABEL version=""
LABEL maintainer="Nightah"

# set versions for node and yarn
ARG NODE_VERSION="9.5.0"
ARG YARN_VERSION="1.3.2"

RUN \
echo "**** install build packages ****" && \
apk add --no-cache --virtual=build-dependencies \
    binutils-gold \
    curl \
    g++ \
    gcc \
    gnupg \
    libgcc \
    linux-headers \
    make \
    python && \
echo "**** install runtime packages ****" && \
apk add --no-cache \
    libstdc++ && \
echo "**** build node and yarn binaries ****" && \
for key in \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    56730D5401028683275BD23C23EFEFE93C4CFFFE \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    6A010C5166006599AA17F08146C2130DFD2497F5 ; \
do \
    gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" || \
    gpg --keyserver hkp://keyserver.pgp.com:80 --recv-keys "$key" || \
    gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" ; \
done && \
curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" && \
curl -SLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" && \
gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc && \
grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - && \
tar -xf "node-v$NODE_VERSION.tar.xz" && \
cd "node-v$NODE_VERSION" && \
./configure && \
make -j$(getconf _NPROCESSORS_ONLN) && \
make install && \
cd .. && \
curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" && \
curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" && \
gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz && \
mkdir -p /opt/yarn && \
tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/yarn --strip-components=1 && \
ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn && \
ln -s /opt/yarn/bin/yarn /usr/local/bin/yarnpkg && \
echo "**** cleanup ****" && \
apk del --purge \
    build-dependencies && \
rm -rf \
    node-v$NODE_VERSION* \
    yarn-v$YARN_VERSION* \
    SHASUMS256.txt* \
    /tmp/*

ENTRYPOINT ["/init"]
