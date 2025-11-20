#!/usr/bin/env bash

# Deploy the static frontend (frontend/app/out) to a dedicated branch.
# Inspired by the user's legacy script, but tailored for the Next.js build.

set -euo pipefail

APP_DIR="frontend/app"
BUILD_DIR="${APP_DIR}/out"
WORK_BRANCH="deploy-build"
TARGET_BRANCH="deploy"
BUILD_COMMAND="pnpm build"

if [[ ! -d "${APP_DIR}" ]]; then
  echo "Error: ${APP_DIR} not found. Run this script from the repository root." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: working tree is dirty. Commit or stash changes before deploying." >&2
  exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

git branch -D "${WORK_BRANCH}" >/dev/null 2>&1 || true
git checkout -b "${WORK_BRANCH}"

rm -rf "${BUILD_DIR}"

(
  cd "${APP_DIR}"
  ${BUILD_COMMAND}
)

git add "${BUILD_DIR}" -f

COMMIT_MSG="Deploy frontend $(date --iso-8601=seconds)"
if [[ $# -gt 0 ]]; then
  COMMIT_MSG="$*"
fi
git commit -m "${COMMIT_MSG}"

git branch -D "${TARGET_BRANCH}" >/dev/null 2>&1 || true
git subtree split --prefix="${BUILD_DIR}" -b "${TARGET_BRANCH}"
git push -f origin "${TARGET_BRANCH}"

git checkout "${CURRENT_BRANCH}"
git branch -D "${WORK_BRANCH}" >/dev/null 2>&1 || true
git branch -D "${TARGET_BRANCH}" >/dev/null 2>&1 || true
