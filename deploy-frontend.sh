#!/usr/bin/env bash

# Deploy the static frontend (frontend/app/out) to a dedicated branch.
# Usage:
#   ./deploy-frontend.sh            # production -> pushes to remote "origin", branch "deploy"
#   ./deploy-frontend.sh --staging  # staging    -> pushes to remote "staging", branch "deploy"
# Any additional arguments become the commit message for the deployment commit.
# Ensure the target remote exists (e.g. git remote add staging <url>).

set -euo pipefail

APP_DIR="frontend/app"
BUILD_DIR="${APP_DIR}/out"
REPO_ROOT="$(pwd)"
BUILD_COMMAND="pnpm build"

if [[ ! -d "${APP_DIR}" ]]; then
  echo "Error: ${APP_DIR} not found. Run this script from the repository root." >&2
  exit 1
fi

env_name="production"
if [[ ${1:-} == "--staging" || ${1:-} == "-s" ]]; then
  env_name="staging"
  shift
fi

REMOTE="origin"
TARGET_BRANCH="deploy"
if [[ "${env_name}" == "staging" ]]; then
  REMOTE="staging"
fi

if ! git remote get-url "${REMOTE}" >/dev/null 2>&1; then
  echo "Error: remote '${REMOTE}' not found. Configure it with 'git remote add ${REMOTE} <url>'." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: working tree is dirty. Commit or stash changes before deploying." >&2
  exit 1
fi

CLEANUP_DIR=""
cleanup() {
  if [[ -n "${CLEANUP_DIR}" && -d "${CLEANUP_DIR}" ]]; then
    git worktree remove --force "${CLEANUP_DIR}" >/dev/null 2>&1 || true
    rm -rf "${CLEANUP_DIR}"
  fi
}
trap cleanup EXIT

rm -rf "${BUILD_DIR}"

(
  cd "${APP_DIR}"
  ${BUILD_COMMAND}
)

WORKTREE_DIR="$(mktemp -d -t deploy-worktree-XXXXXXXX)"
CLEANUP_DIR="${WORKTREE_DIR}"

# Prepare local branch from remote if it exists; otherwise create an orphan later.
if git ls-remote --exit-code "${REMOTE}" "refs/heads/${TARGET_BRANCH}" >/dev/null 2>&1; then
  git fetch "${REMOTE}" "${TARGET_BRANCH}:refs/heads/${TARGET_BRANCH}"
  git worktree add --force "${WORKTREE_DIR}" "${TARGET_BRANCH}"
else
  git worktree add --detach "${WORKTREE_DIR}" >/dev/null 2>&1
  (
    cd "${WORKTREE_DIR}"
    git checkout --orphan "${TARGET_BRANCH}"
  )
fi

(
  cd "${WORKTREE_DIR}"
  # Sync build output into the worktree root
  rsync -a --delete --exclude '.git' "${REPO_ROOT}/${BUILD_DIR}/" ./

  git add -A
  COMMIT_MSG="Deploy frontend (${env_name}) $(date --iso-8601=seconds)"
  if [[ $# -gt 0 ]]; then
    COMMIT_MSG="$*"
  fi
  if git diff --cached --quiet; then
    echo "No changes to deploy." >&2
    exit 0
  fi
  git commit -m "${COMMIT_MSG}"
  git push "${REMOTE}" "${TARGET_BRANCH}"
)
