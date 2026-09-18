#!/usr/bin/env bash
set -u

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../libs/common.sh"

resolve_image
resolve_platform_image "${PLATFORM}" || exit 1

case "${PLATFORM}" in
  amd64) ALPINE_ARCH="x86_64"; ELF_MACHINE="62" ;;
  arm64) ALPINE_ARCH="aarch64"; ELF_MACHINE="183" ;;
  armv7) ALPINE_ARCH="armv7"; ELF_MACHINE="40" ;;
esac

REVISION="${BUILDKITE_COMMIT}"
YARN_RELEASE=$(sed -nE 's/^ARG YARN_VERSION="(.*)"$/\1/p' "${DOCKERFILE}")
MARKER="__TEST_OUTPUT__"
FAILURES=0

# Runs a shell script inside the container through /init and with-contenv, the same way the
# image's services run, and returns only the script's output (not the s6 startup banner).
run() {
  local options="$1" script="$2"
  # shellcheck disable=SC2086 # options holds multiple docker run flags and must be word split.
  docker run --rm --platform "${DOCKER_PLATFORM}" ${options} "${PLATFORM_IMAGE}" /command/with-contenv sh -c "echo ${MARKER}; ${script}" 2> /dev/null | sed "1,/^${MARKER}\$/d"
}

check() {
  local description="$1" expected="$2" actual="$3"

  if [[ "${actual}" == "${expected}" ]]; then
    echo "ok - ${description}"
  else
    echo "not ok - ${description}"
    echo "    expected: ${expected}"
    echo "    actual:   ${actual}"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "--- :label: Image metadata [${DOCKER_PLATFORM}]"
check "image platform is ${DOCKER_PLATFORM}" "${DOCKER_PLATFORM}" \
  "$(docker image inspect -f '{{.Os}}/{{.Architecture}}{{with .Variant}}/{{.}}{{end}}' "${PLATFORM_IMAGE}" | sed 's|^linux/arm64/v8$|linux/arm64|')"
check "entrypoint is /init" '["/init"]' "$(docker image inspect -f '{{json .Config.Entrypoint}}' "${PLATFORM_IMAGE}")"
check "version label is ${BUILD_TAG}" "${BUILD_TAG}" "$(docker image inspect -f '{{index .Config.Labels "version"}}' "${PLATFORM_IMAGE}")"
check "build_date label is set" "set" "$(docker image inspect -f '{{with index .Config.Labels "build_date"}}set{{end}}' "${PLATFORM_IMAGE}")"
check "OCI revision label is ${REVISION}" "${REVISION}" "$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.revision"}}' "${PLATFORM_IMAGE}")"
check "OCI source label is the GitHub repository" "https://github.com/${GITHUB_REPOSITORY}" \
  "$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.source"}}' "${PLATFORM_IMAGE}")"
check "OCI version label is ${BUILD_TAG}" "${BUILD_TAG}" "$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.version"}}' "${PLATFORM_IMAGE}")"
check "OCI created label is an RFC 3339 timestamp" "valid" \
  "$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.created"}}' "${PLATFORM_IMAGE}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' && echo valid)"

echo "--- :alpine: Inherited base image"
check "apk architecture is ${ALPINE_ARCH}" "${ALPINE_ARCH}" "$(run "" "apk --print-arch")"
check "abc passwd entry" "abc:911:911:/config:/bin/false" "$(run "" "getent passwd abc | cut -d: -f1,3,4,6,7")"
check "container keeps s6 supervision" "0" "$(docker run --rm --platform "${DOCKER_PLATFORM}" "${PLATFORM_IMAGE}" true > /dev/null 2>&1; echo $?)"

echo "--- :nodejs: Node ${NODE_RELEASE}"
check "node version is ${NODE_RELEASE}" "v${NODE_RELEASE}" "$(run "" "node --version")"
check "node is built for ${ALPINE_ARCH}" "${ELF_MACHINE}" "$(run "" "od -An -tu2 -j18 -N2 /usr/local/bin/node" | xargs)"
check "nodejs symlink resolves to node" "/usr/local/bin/node" "$(run "" "readlink -f /usr/local/bin/nodejs")"
check "node can bind a privileged port unprivileged" "ok" \
  "$(run "-u 911" "node -e 'require(\"net\").createServer().listen(80,()=>{console.log(\"ok\");process.exit(0)})'")"
check "npm version matches the bundled npm" "ok" "$(run "" "npm --version > /dev/null 2>&1 && echo ok")"

echo "--- :yarn: Yarn ${YARN_RELEASE}"
check "yarn version is ${YARN_RELEASE}" "${YARN_RELEASE}" "$(run "" "yarn --version")"
check "yarnpkg version is ${YARN_RELEASE}" "${YARN_RELEASE}" "$(run "" "yarnpkg --version")"
check "yarn is installed under /opt" "/opt/yarn-v${YARN_RELEASE}/bin/yarn" "$(run "" "readlink -f /usr/local/bin/yarn")"

echo "--- :package: Packages"
check "runtime packages are installed" "libstdc++ libcap" \
  "$(run "" "for p in libstdc++ libcap; do apk info -e \$p; done" | xargs)"
check "build dependencies are removed" "" \
  "$(run "" "for p in build-dependencies build-dependencies-full build-dependencies-yarn curl gnupg tar; do apk info -e \$p; done" | xargs)"
check "no build artefacts are left behind" "" \
  "$(run "" "ls -d /node-v* /yarn-v* /SHASUMS256.txt* /tmp/* 2> /dev/null" | xargs)"

if [[ ${FAILURES} -gt 0 ]]; then
  echo "^^^ +++"
  echo "${FAILURES} check(s) failed"
  exit 1
fi

echo "All checks passed"
