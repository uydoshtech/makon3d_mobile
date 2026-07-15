#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tool/bump_version.sh [{build|patch|minor|major}] [--commit] [--push]

Bumps version in pubspec.yaml (format: x.y.z+build).

Bump types:
  build   Increment build number only (default)
  patch   Increment patch version, reset build to 1
  minor   Increment minor version, reset patch and build
  major   Increment major version, reset minor, patch, and build

Options:
  --bump <type>   Bump type (alternative to positional argument)
  --commit        Git commit the version bump
  --push          Push after commit (requires --commit)
EOF
}

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "Error: not inside a git repository."
  exit 1
fi

cd "${REPO_ROOT}"

BUMPTYPE="build"
DO_COMMIT="false"
DO_PUSH="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    build|patch|minor|major)
      BUMPTYPE="$1"
      shift
      ;;
    --bump)
      BUMPTYPE="${2:-}"
      shift 2
      ;;
    --commit)
      DO_COMMIT="true"
      shift
      ;;
    --push)
      DO_PUSH="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ "${DO_PUSH}" == "true" && "${DO_COMMIT}" != "true" ]]; then
  echo "Error: --push requires --commit."
  exit 2
fi

if [[ "${BUMPTYPE}" != "build" && "${BUMPTYPE}" != "patch" && "${BUMPTYPE}" != "minor" && "${BUMPTYPE}" != "major" ]]; then
  echo "Error: invalid bump type: ${BUMPTYPE}"
  usage
  exit 2
fi

PUBSPEC="${REPO_ROOT}/pubspec.yaml"
if [[ ! -f "${PUBSPEC}" ]]; then
  echo "Error: pubspec.yaml not found."
  exit 1
fi

VERSION_RAW="$(grep -m1 -E '^version:[[:space:]]+' "${PUBSPEC}" | sed -E 's/^version:[[:space:]]+//; s/[[:space:]]*#.*//; s/[[:space:]]+$//')"
if [[ ! "${VERSION_RAW}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
  echo "Error: could not parse version from pubspec.yaml (expected x.y.z+build): ${VERSION_RAW}"
  exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"
BUILD="${BASH_REMATCH[4]}"

case "${BUMPTYPE}" in
  build)
    BUILD=$((BUILD + 1))
    ;;
  patch)
    PATCH=$((PATCH + 1))
    BUILD=1
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    BUILD=1
    ;;
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    BUILD=1
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}+${BUILD}"
sed -i.bak -E "s/^version:[[:space:]]+.*/version: ${NEW_VERSION}/" "${PUBSPEC}"
rm -f "${PUBSPEC}.bak"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  echo -e "Updated pubspec.yaml to version: \033[33m${MAJOR}.${MINOR}.${PATCH}\033[0m\033[32m+${BUILD}\033[0m"
else
  echo "Updated pubspec.yaml to version: ${NEW_VERSION}"
fi

if [[ "${DO_COMMIT}" == "true" ]]; then
  git add pubspec.yaml
  if ! git diff --cached --quiet; then
    git commit -m "Bump version to ${NEW_VERSION}"
    if [[ "${DO_PUSH}" == "true" ]]; then
      git push
    fi
  fi
fi

echo "Done. Version is now ${NEW_VERSION}."
