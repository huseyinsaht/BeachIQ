#!/usr/bin/env bash
#
# Make sure every task on the GitHub Project board exists as a real issue.
#
# Board items come in two flavours: real issues (nothing to do) and draft items
# (board-only notes that automation and `gh issue list` cannot see). This script
# converts every draft item into an issue in the repo; the item stays on the
# board and now points at the new issue.
#
# Requirements: gh (GitHub CLI), logged in with the `project` scope:
#   gh auth refresh -s project
#
# Usage:
#   scripts/sync-project-tasks-to-issues.sh [--dry-run]
#
# Overridable via environment:
#   OWNER (huseyinsaht)   PROJECT_NUMBER (1)   REPO (huseyinsaht/BeachIQ)

set -euo pipefail

OWNER="${OWNER:-huseyinsaht}"
PROJECT_NUMBER="${PROJECT_NUMBER:-1}"
REPO="${REPO:-huseyinsaht/BeachIQ}"
DRY_RUN=0

case "${1:-}" in
  --dry-run) DRY_RUN=1 ;;
  "") ;;
  *) echo "Unknown argument: $1 (only --dry-run is supported)" >&2; exit 2 ;;
esac

command -v gh >/dev/null 2>&1 || { echo "gh (GitHub CLI) is required: https://cli.github.com" >&2; exit 1; }

repo_id="$(gh repo view "$REPO" --json id --jq .id)"

# Lists "<item id>\t<title>" for every draft item on the board (all pages).
# The board belongs to a user account; use organization(login:) for an org.
list_drafts() {
  gh api graphql --paginate \
    -F owner="$OWNER" -F number="$PROJECT_NUMBER" \
    -f query='
      query($owner: String!, $number: Int!, $endCursor: String) {
        user(login: $owner) {
          projectV2(number: $number) {
            items(first: 100, after: $endCursor) {
              pageInfo { hasNextPage endCursor }
              nodes {
                id
                content { __typename ... on DraftIssue { title } }
              }
            }
          }
        }
      }' \
    --jq '.data.user.projectV2.items.nodes[]
          | select(.content.__typename == "DraftIssue")
          | [.id, .content.title] | @tsv'
}

convert_to_issue() {
  gh api graphql \
    -F itemId="$1" -F repoId="$repo_id" \
    -f query='
      mutation($itemId: ID!, $repoId: ID!) {
        convertProjectV2DraftIssueItemToIssue(input: {itemId: $itemId, repositoryId: $repoId}) {
          item { content { ... on Issue { number url } } }
        }
      }' \
    --jq '.data.convertProjectV2DraftIssueItemToIssue.item.content | "#\(.number) \(.url)"'
}

drafts="$(list_drafts)"

if [ -z "$drafts" ]; then
  echo "No draft items on project $PROJECT_NUMBER: every task is already an issue."
  exit 0
fi

count=0
while IFS=$'\t' read -r item_id title; do
  [ -n "$item_id" ] || continue
  count=$((count + 1))
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] would create issue in $REPO: $title"
  else
    echo "Creating issue: $title"
    echo "  -> $(convert_to_issue "$item_id")"
  fi
done <<< "$drafts"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "$count draft item(s) would be converted."
else
  echo "Done: $count draft item(s) converted to issues in $REPO."
fi
