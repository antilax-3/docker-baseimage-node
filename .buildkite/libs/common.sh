#!/usr/bin/env bash

# .buildkite/libs/common.sh
#
# Shared values and helpers for the pipeline generator, hooks and step scripts.
# Source with a BASH_SOURCE-relative path so it works regardless of CWD:
#   source "$(dirname "${BASH_SOURCE[0]}")/libs/common.sh"        # from .buildkite/
#   source "$(dirname "${BASH_SOURCE[0]}")/../libs/common.sh"     # from .buildkite/hooks/ and .buildkite/steps/
#
# The variables set here and by resolve_image() are read by the sourcing files, which shellcheck can't see when
# linting this file in isolation.
# shellcheck disable=SC2034

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GITHUB_REPOSITORY="antilax-3/docker-baseimage-node"
DOCKER_REPOSITORY="antilax3/node"
REGISTRY="docker.io"
# Platforms every image is built for, by the short name used in test step keys and labels. Node is amd64 only:
# unofficial-builds publishes no musl tarball for the pinned release on any other architecture.
PLATFORMS="amd64"

DOCKERFILE="${REPOSITORY_ROOT}/Dockerfile"
# The Node release, e.g. 24.3.0, from the Dockerfile's NODE_VERSION build arg, and its series (24.3) and major
# version (24).
NODE_RELEASE=$(sed -nE 's/^ARG NODE_VERSION="([0-9]+\.[0-9]+\.[0-9]+)"$/\1/p' "${DOCKERFILE}")
NODE_SERIES="${NODE_RELEASE%.*}"
NODE_MAJOR="${NODE_RELEASE%%.*}"

# Test jobs keyed "test-<platform>" get their platform from the step key, so steps don't each need it in env.
if [[ "${BUILDKITE_STEP_KEY:-}" == test-* ]]; then
  PLATFORM="${BUILDKITE_STEP_KEY#test-}"
fi

# Prints the Docker platform for a short platform name, e.g. armv7 -> linux/arm/v7.
docker_platform() {
  case "${1}" in
    amd64) echo "linux/amd64" ;;
    arm64) echo "linux/arm64" ;;
    armv7) echo "linux/arm/v7" ;;
  esac
}

# Returns success for pushes to master, the only builds that publish the latest and version tags.
master() {
  [[ "${BUILDKITE_BRANCH}" == "master" ]] && [[ "${BUILDKITE_PULL_REQUEST}" == "false" ]]
}

# Makes a branch name safe to use in a Docker tag.
sanitize_tag() {
  echo "${1}" | sed -E 's/[^A-Za-z0-9_.-]+/-/g'
}

# Resolves the image details for the build. Sets as globals:
#   BUILD_TAG - the build-scoped tag, e.g. BK12, also used as the version label/build arg
#   IMAGE     - the fully qualified build-scoped image the test step pulls
#   TAGS      - the tags pushed for the build context, following antilax-3/docker-baseimage-alpine:
#                 local branch -> <branch> with unsafe characters replaced, e.g. renovate/node-24.x -> renovate-node-24.x
#                 fork PRs     -> PR<number> (Buildkite prefixes fork branch names with owner:)
#                 master       -> latest, <major>, <series> and <release>, e.g. latest 24 24.3 24.3.0
#               and always BK<build>
resolve_image() {
  BUILD_TAG="BK${BUILDKITE_BUILD_NUMBER}"
  IMAGE="${REGISTRY}/${DOCKER_REPOSITORY}:${BUILD_TAG}"
  TAGS=""

  if [[ "${BUILDKITE_BRANCH}" != "master" ]] && [[ ! "${BUILDKITE_BRANCH}" =~ .*:.* ]]; then
    TAGS="$(sanitize_tag "${BUILDKITE_BRANCH}")"
  elif [[ "${BUILDKITE_BRANCH}" =~ .*:.* ]]; then
    TAGS="PR${BUILDKITE_PULL_REQUEST}"
  elif master; then
    TAGS="latest ${NODE_MAJOR} ${NODE_SERIES} ${NODE_RELEASE}"
  fi

  TAGS+=" ${BUILD_TAG}"
}

# Resolves IMAGE (see resolve_image) to the manifest for one platform. Sets as globals:
#   DOCKER_PLATFORM - the Docker platform, e.g. linux/arm/v7
#   PLATFORM_IMAGE  - IMAGE pinned to that platform's manifest digest; tests of different platforms can share a
#                     Docker daemon, and pulling the multi-platform tag for each would race over the local tag.
#
# The pre-command hook exports both, so the command and later hooks reuse them instead of querying the registry again.
# Registry lookups are retried, as Docker Hub intermittently fails token requests. Returns non-zero if no digest resolves.
#
# $1 - the short platform name, e.g. armv7
resolve_platform_image() {
  local attempt digest

  DOCKER_PLATFORM=$(docker_platform "${1}")

  if [[ "${PLATFORM_IMAGE:-}" == "${IMAGE%:*}@sha256:"* ]]; then
    return 0
  fi

  for attempt in 1 2 3 4 5; do
    digest=$(docker buildx imagetools inspect "${IMAGE}" --format '{{json .Manifest}}' | jq -r --arg platform "${DOCKER_PLATFORM}" \
      '.manifests[] | select((.platform.os + "/" + .platform.architecture + (if .platform.variant then "/" + .platform.variant else "" end)) == $platform) | .digest')

    if [[ "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
      PLATFORM_IMAGE="${IMAGE%:*}@${digest}"
      return 0
    fi

    [[ ${attempt} -lt 5 ]] && echo "Unable to resolve the ${DOCKER_PLATFORM} digest of ${IMAGE}, retrying (${attempt}/5)" >&2 && sleep $((attempt * 5))
  done

  echo "Unable to resolve the ${DOCKER_PLATFORM} digest of ${IMAGE}" >&2
  PLATFORM_IMAGE=""
  return 1
}
