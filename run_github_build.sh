#!/usr/bin/env bash

set -euo pipefail

OWNER="jaeyk"
REPO="us_ac_career_for_korean_students"
WORKFLOW_FILE="deploy.yml"
REMOTE="${REMOTE:-origin}"
REF="${REF:-main}"
MODE="${1:-auto}"

usage() {
  cat <<'EOF'
Usage:
  ./run_github_build.sh auto
  ./run_github_build.sh dispatch
  ./run_github_build.sh push

Modes:
  auto      Use workflow_dispatch when GITHUB_TOKEN is set; otherwise use an empty commit + git push.
  dispatch  Trigger GitHub Actions via the GitHub API. Requires GITHUB_TOKEN.
  push      Trigger the existing push-based workflow by creating and pushing an empty commit over SSH.

Optional environment variables:
  REF=main
  REMOTE=origin
EOF
}

dispatch_workflow() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required but not installed." >&2
    exit 1
  fi

  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "Error: dispatch mode requires GITHUB_TOKEN." >&2
    exit 1
  fi

  api_url="https://api.github.com/repos/${OWNER}/${REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches"

  echo "Triggering GitHub Actions workflow '${WORKFLOW_FILE}' on ref '${REF}' via API..."

  http_code="$(
    curl -sS -o /tmp/github-workflow-dispatch-response.txt -w "%{http_code}" \
      -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${api_url}" \
      -d "{\"ref\":\"${REF}\"}"
  )"

  if [[ "${http_code}" != "204" ]]; then
    echo "Failed to trigger workflow. HTTP ${http_code}." >&2
    cat /tmp/github-workflow-dispatch-response.txt >&2
    exit 1
  fi
}

push_trigger() {
  if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is required but not installed." >&2
    exit 1
  fi

  current_branch="$(git branch --show-current)"
  if [[ "${current_branch}" != "${REF}" ]]; then
    echo "Error: push mode must be run from branch '${REF}', but current branch is '${current_branch}'." >&2
    exit 1
  fi

  echo "Triggering GitHub Actions by pushing an empty commit to ${REMOTE}/${REF}..."
  git commit --allow-empty -m "Trigger GitHub Actions deploy"
  git push "${REMOTE}" "${REF}"
}

case "${MODE}" in
  auto)
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      dispatch_workflow
    else
      push_trigger
    fi
    ;;
  dispatch)
    dispatch_workflow
    ;;
  push)
    push_trigger
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "Error: unknown mode '${MODE}'." >&2
    usage >&2
    exit 1
    ;;
esac

echo "Workflow trigger sent successfully."
echo "Check progress at:"
echo "https://github.com/${OWNER}/${REPO}/actions/workflows/${WORKFLOW_FILE}"
