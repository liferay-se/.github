#!/usr/bin/env bash
#
# fetch-clones.sh — one command to get, and stay, current with every repo.
#
# Two passes, so new repos and existing ones are handled together:
#
#   1. clone  — ask GitHub which org repos you can see, clone the missing ones
#               as siblings of this index clone
#   2. update — for every repo already on disk, fetch origin and rebase onto it
#               (equivalent to: git fetch origin && git pull --rebase)
#
# The update pass works from the directory, not from the GitHub API, so it also
# covers the .github / .github-private index clones and any personal or
# unrelated repo cloned alongside them.
#
# Usage:
#   ./fetch-clones.sh               # clone into / update the parent of this repo
#   ./fetch-clones.sh ~/somewhere   # use an explicit target directory
#   ./fetch-clones.sh --autostash   # stash local edits, rebase, reapply them
#
# Repos are never left mid-rebase: a rebase that hits conflicts is aborted and
# reported, for you to redo by hand.
#
# Requires the GitHub CLI (gh), authenticated: https://cli.github.com

set -euo pipefail

ORG="liferay-se"

AUTOSTASH=""
TARGET=""

for arg in "$@"; do
	case "${arg}" in
		--autostash) AUTOSTASH="--autostash" ;;
		-*) echo "error: unknown option ${arg}" >&2; exit 2 ;;
		*) TARGET="${arg}" ;;
	esac
done

# Default target: the directory that contains this index clone (e.g. ~/Assets)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${TARGET:-$(dirname "${SCRIPT_DIR}")}"

echo "Syncing ${ORG} repos in ${TARGET}"

# Newline-delimited rather than an array: empty arrays are an "unbound
# variable" error under `set -u` in the bash 3.2 that ships with macOS.
ATTENTION=""
FAILED=0
CLONED=" "

note_attention() {
	ATTENTION="${ATTENTION}  ${1}
"
}

# ---------------------------------------------------------------- clone pass

if ! command -v gh >/dev/null 2>&1; then
	echo "note   gh not found — skipping the clone pass (see https://cli.github.com)"
	note_attention "gh not installed: new repos were not cloned"
else
	if ! REPOS="$(gh repo list "${ORG}" --limit 200 --json name --jq '.[].name' | sort)"; then
		echo "FAIL   could not list ${ORG} repos (is gh authenticated?)"
		note_attention "gh repo list failed: new repos were not cloned"
		FAILED=1
		REPOS=""
	fi

	# Here-string, not a pipe: a piped `while` runs in a subshell, where the
	# bookkeeping below would be discarded.
	while read -r name; do

		[ -n "${name}" ] || continue

		# Skip the org-profile/index repos themselves
		case "${name}" in
			.github|.github-private) continue ;;
		esac

		if [ -d "${TARGET}/${name}/.git" ]; then
			continue
		fi

		echo "clone  ${name}"

		if gh repo clone "${ORG}/${name}" "${TARGET}/${name}" -- --quiet; then
			CLONED="${CLONED}${name} "
		else
			echo "FAIL   ${name} (clone failed)"
			note_attention "${name}: clone failed"
			FAILED=1
		fi

	done <<< "${REPOS}"
fi

# --------------------------------------------------------------- update pass

shopt -s nullglob dotglob

for dir in "${TARGET}"/*/; do

	name="$(basename "${dir}")"

	[ -d "${dir}.git" ] || continue

	# Just cloned above — already current, and already reported.
	case "${CLONED}" in
		*" ${name} "*) continue ;;
	esac

	branch="$(git -C "${dir}" symbolic-ref --quiet --short HEAD || true)"
	if [ -z "${branch}" ]; then
		echo "skip   ${name} (detached HEAD)"
		note_attention "${name}: detached HEAD"
		continue
	fi

	if ! git -C "${dir}" remote get-url origin >/dev/null 2>&1; then
		echo "skip   ${name} (no origin remote)"
		note_attention "${name}: no origin remote"
		continue
	fi

	if ! git -C "${dir}" fetch --quiet --prune origin; then
		echo "FAIL   ${name} (fetch failed)"
		note_attention "${name}: fetch failed"
		FAILED=1
		continue
	fi

	# Prefer the configured tracking branch; fall back to the same-named branch
	# on origin for clones that were never set up to track one.
	upstream="$(git -C "${dir}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
	if [ -z "${upstream}" ]; then
		if git -C "${dir}" rev-parse --verify --quiet "origin/${branch}" >/dev/null; then
			upstream="origin/${branch}"
		else
			echo "skip   ${name} (${branch} has no branch on origin)"
			note_attention "${name}: ${branch} has no branch on origin"
			continue
		fi
	fi

	read -r ahead behind < <(git -C "${dir}" rev-list --left-right --count "HEAD...${upstream}")

	if [ "${behind}" -eq 0 ]; then
		echo "current ${name} (${branch})"
		continue
	fi

	# Untracked files neither block a rebase nor get stashed, so only tracked
	# modifications count as dirty here.
	if [ -z "${AUTOSTASH}" ] && ! git -C "${dir}" diff --quiet HEAD; then
		echo "skip   ${name} (uncommitted changes — re-run with --autostash)"
		note_attention "${name}: uncommitted changes"
		continue
	fi

	if git -C "${dir}" rebase ${AUTOSTASH} "${upstream}" >/dev/null 2>&1; then
		# A rebase that reapplies an autostash still exits 0 when that reapply
		# conflicts, leaving conflict markers in the tree — so check for them.
		if [ -n "$(git -C "${dir}" ls-files --unmerged)" ]; then
			echo "FAIL   ${name} (rebased, but reapplying your local edits conflicted)"
			note_attention "${name}: autostash reapply conflicted — resolve the conflict markers; your edits are also still in 'git stash list'"
			FAILED=1
		elif [ "${ahead}" -gt 0 ]; then
			echo "update ${name} (+${behind} from ${upstream}, ${ahead} local replayed)"
		else
			echo "update ${name} (+${behind} from ${upstream})"
		fi
	else
		git -C "${dir}" rebase --abort >/dev/null 2>&1 || true
		echo "FAIL   ${name} (rebase conflicts — resolve by hand)"
		note_attention "${name}: rebase conflicts, left untouched"
		FAILED=1
	fi

done

if [ -n "${ATTENTION}" ]; then
	echo
	echo "Needs attention:"
	printf '%s' "${ATTENTION}"
fi

echo "Done."
exit "${FAILED}"
