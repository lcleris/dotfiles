---
name: verify-bootstrap
description: Check that the dotfiles install cannot break a Mac. Use in ~/dotfiles before committing any change to scripts/bootstrap.sh, scripts/cliproxy-secrets.sh, .gitattributes, or to which folders under .config/ or .claude/ exist, and whenever someone asks whether the install is safe to run on an existing machine.
---

# Verify the bootstrap install

`scripts/verify-bootstrap.py` runs the real `scripts/bootstrap.sh link cliproxyapi nushell` in a throwaway HOME and a throwaway copy of the repo. It does this once for every combination of the starting states below, and checks seven properties on the result. Nothing touches the real HOME, Homebrew, or Keychain.

## The properties

Each one is a promise the install makes, and the harm if it breaks.

| | Property | Harm if broken |
|---|---|---|
| P1 | The steps exit 0 from every starting state. | `set -e` stops the install halfway, and later steps never run. |
| P2 | Every tracked file under `.config/` and `.claude/` resolves from its home path to the repo file. No other link points into the repo. `$(brew --prefix)/etc/cliproxyapi.conf` reaches the repo config, the brew service starts, and both git filters are set. | A tool silently runs on a stale or missing config, or a config gets linked to the wrong place. |
| P3 | Every file the user already had is still readable. It stays at its path, is adopted into the repo at that path, or survives in a `<name>.bak.<time>` copy of itself or of a folder holding it. | User data is gone. |
| P4 | The install changes the repo only by adopting a conflicting user file (`stow --adopt`). | Generated or machine-local files end up in a public git repo. |
| P5 | `~/.config/herdr`, `~/.claude` and `~/.omp` are real directories, and `~/.cli-proxy-api` is a real directory with mode 700. | Logs, OAuth tokens or agent databases get written into the repo, or tokens become readable by other users. |
| P6 | A second run exits 0 and leaves exactly the same state. | Every rerun drifts the machine further. |
| P7 | All 6 orders of the three steps end in the same state, from a clean HOME and from a used one. | `bootstrap.sh <steps>` gives a different machine depending on argument order. |

## Bounds and assumptions

The starting states are every combination of these slots, 480 in all (`SLOTS` in the script):

| Slot | States |
|---|---|
| `~/.config/fish` (stands in for every folder stowed into `~/.config`) | absent, symlink to elsewhere, real dir with a user file, real dir with a user `config.fish` that conflicts with the repo's, plain file |
| `~/.config/herdr` | absent, real dir with `herdr.log`, the old layout where stow folded the whole folder into a link to the repo |
| `~/.claude/commands` | absent, real dir with a user command |
| `~/.claude/settings.json` | absent, the file Claude Code writes on first launch |
| `~/.cli-proxy-api` | absent, mode-755 dir holding an OAuth token |
| `~/.omp/agent` | absent, real dir holding `agent.db` |
| `~/Library/Application Support/nushell/env.nu` | absent, a hand-written file |

Assumptions:
- `brew` is a fake that answers `--prefix` and logs every other call.
- `USER` is set to a name with no Keychain entry, so the cliproxy smudge filter keeps its placeholders. That keeps real secrets out of `/tmp`, and it also means the Keychain branch of `scripts/cliproxy-secrets.sh` is not exercised.
- `stow`, `git` and `jq` are the real versions on PATH.

Not covered:
- The steps `preflight`, `secrets`, `homebrew`, `clone`, `packages`, `shells` and `tools`. They talk to the network, sudo, the Keychain or Homebrew.
- Whether the Brewfile installs cleanly.
- Folders under `~/.config` other than `fish`, beyond the assumption that stow treats them the same way.
- States outside the table, such as unreadable files or a full disk.

## Run it

```bash
cd ~/dotfiles
cpuq python3 scripts/verify-bootstrap.py   # or: mise run verify. Drop cpuq if it is not on PATH.
```

It needs macOS (it copies with `cp -c`), python3, stow, git and jq. It takes about 100 s on 10 cores, and `-j N` sets the number of parallel cases. The exit code is 0 only when nothing fails.

Each `FAIL` line names one violation, how many starting states hit it, and one of them as `slot=state+…`. The last line counts what ran.

## Known findings

None at the sync commit: the check passes. Commit 25585d9 fixed the three it first reported, which the Ansible playbook already had: a real `~/.claude/commands` was deleted with `rm -rf`, an old folded `~/.config/herdr` link stayed folded, and a plain file where a stowed folder belongs made stow abort. The last three rows of the break table bring each one back.

When the check reports a finding you do not fix, list it here with its steps, so the next agent can tell it from a new break.

## A real bug or a modeling error?

A new `FAIL` is a real bug when the step really did that on disk. Rerun the one case by hand to see it:

```bash
r=$(mktemp -d); mkdir -p "$r/home" "$r/bin" "$r/prefix/etc"
git clone -q ~/dotfiles "$r/dotfiles"; cp ~/dotfiles/scripts/bootstrap.sh "$r/dotfiles/scripts/"
printf '#!/bin/sh\n[ "$1" = --prefix ] && echo %s/prefix || echo "brew $*"\n' "$r" > "$r/bin/brew"; chmod +x "$r/bin/brew"
# seed the case's slot states under $r/home, then:
HOME="$r/home" USER=verify-bootstrap-nobody DOTFILES_DIR="$r/dotfiles" PATH="$r/bin:$PATH" \
  bash "$r/dotfiles/scripts/bootstrap.sh" link cliproxyapi nushell
```

It is a modeling error when the script and the harness disagree about what the install should do. That happens in four places:

- **`home_target()`** restates where each stow call in `step_link` and `step_cliproxyapi` puts a repo path. If you add, remove or retarget a stow call or an `--ignore`, change `home_target()` the same way. That function plus the stow calls are the contract.
- **P5's list** of real-directory promises. If a step starts keeping a new folder real, add it.
- **`STEPS`** lists the steps that run. If a new step writes into HOME without the network or sudo, add it, and add a slot for what it meets.
- **Snapshot normalization** replaces the case path with `CASE` and backup timestamps with `TIME`. A P6 or P7 diff that shows only a value like that is a harness bug.

Never weaken a property or drop a slot just to get a pass. If the code is right and a property is wrong for a reason the user agrees with, change the property, update the table above, and say why in the commit.

## When you change the verification

Reprove that it can still fail. Break the code in each of these ways, one at a time, and run the check. Each one must add the listed violation on top of the known findings, if any. Then restore the file with `git checkout -- scripts/bootstrap.sh`.

| Break in `scripts/bootstrap.sh` | Must add |
|---|---|
| remove `--adopt` from `restow()` | P1 |
| change `--ignore='^(omp\|cli-proxy-api)$'` to `--ignore='^omp$'` | P2 stray link `~/.config/cli-proxy-api` |
| drop `--ignore='^skills$'` from the `.claude` stow | P2 stray link `~/.claude/skills` |
| remove the `cp "$1" "$1.bak…"` line in `write_kept` | P3 `env.nu` lost |
| set `dir="$DOTFILES_DIR/.config/nushell"` in `step_nushell` | P4 |
| remove `chmod 700 "$HOME/.cli-proxy-api"` | P5 mode |
| drop the `grep -qxF .DS_Store … \|\|` guard | P6 |
| add `rm -f "$HOME/.cli-proxy-api/config.yaml"` at the top of `step_link` | P7 |
| drop `herdr` from the stale-link loop in `step_link` | P5 `~/.config/herdr` |
| replace `done < <(find …)` in `step_link` with `done < /dev/null` | P1 |
| replace `move_aside "$HOME/.claude/commands"` with `rm -rf "$HOME/.claude/commands"` | P3 `my-command.md` lost |

## Coverage and sync

The verification describes these files and functions:

- `scripts/bootstrap.sh`, in `step_link`, `step_cliproxyapi`, `step_nushell`, `write_kept`, `restow`, `move_aside` and `main`'s step dispatch
- `scripts/cliproxy-secrets.sh`, the smudge path with no Keychain entry
- `.gitattributes`, the filter assignments
- the folder layout of `.config/` and `.claude/`, through `home_target()`

**Sync commit:** `25585d996009e9420160d5312827c0929e37d281`

To see whether the verification needs another look:

```bash
git diff --stat 25585d99..HEAD -- scripts/bootstrap.sh scripts/cliproxy-secrets.sh .gitattributes
git diff --stat 25585d99..HEAD --diff-filter=AD -- .config .claude
```

If that commit is no longer in the history (after a squash merge), diff from the commit that last changed this file instead: `git log -1 --format=%H -- .claude/skills/verify-bootstrap/SKILL.md`.

Move the sync commit forward only after you have read the covered changes, updated the harness where they change the contract, run the check, and seen it pass or show exactly the known findings. Run the break table too if you changed the harness.
