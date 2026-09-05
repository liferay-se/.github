#!/usr/bin/env bash
#
# clone-all.sh — clone every liferay-se repo as a sibling of this index clone.
#
# Usage:
#   ./clone-all.sh              # clones into the parent of this repo's directory
#   ./clone-all.sh ~/somewhere  # clones into an explicit target directory
#
# Requires the GitHub CLI (gh), authenticated: https://cli.github.com

set -euo pipefail

ORG="liferay-se"

command -v gh >/dev/null 2>&1 || {
	echo "error: GitHub CLI (gh) is required and must be authenticated (gh auth login)" >&2
	exit 1
}

# Default target: the directory that contains this index clone (e.g. ~/Assets)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$(dirname "${SCRIPT_DIR}")}"

echo "Cloning ${ORG} repos into ${TARGET}"

gh repo list "${ORG}" --limit 200 --json name --jq '.[].name' | sort | while read -r name; do

	# Skip the org-profile/index repos themselves
	case "${name}" in
		.github|.github-private) continue ;;
	esac

	if [ -d "${TARGET}/${name}/.git" ]; then
		echo "skip   ${name} (already present)"
	else
		echo "clone  ${name}"
		gh repo clone "${ORG}/${name}" "${TARGET}/${name}" -- --quiet
	fi
done

echo "Done."
