# Liferay Sales Engineering

Reusable [Liferay](https://www.liferay.com) workspaces, demos, and reference implementations from the Liferay Sales Engineering team.

These projects are demos and reference implementations provided as-is. They are not official Liferay products and are not covered by Liferay support.

## Projects

Repositories are opened to the public as they become ready — the first are coming soon.

| Repo | What It Is | Status |
| --- | --- | --- |
| | | Coming soon |

## Clone And Update Everything

Clone this repo, then run [fetch-clones.sh](https://github.com/liferay-se/.github/blob/main/fetch-clones.sh) — every repo you have access to is cloned as a sibling of this one:

```bash
mkdir liferay-se
cd liferay-se
gh repo clone liferay-se/.github
./.github/fetch-clones.sh
```

The script clones whatever your GitHub account can see: the public repos for everyone, plus the private ones if you are an organization member.

Run it again any time to stay current — it is the only command you need. Repos you do not have yet are cloned, and every repo already on disk is fetched and rebased onto its origin branch (`git pull --rebase`), this index clone included. A repo with uncommitted changes is left alone and listed at the end; `--autostash` updates it anyway, setting your edits aside and reapplying them afterward.

```bash
./.github/fetch-clones.sh              # clone what's missing, update the rest
./.github/fetch-clones.sh --autostash  # also update repos with local edits
```
