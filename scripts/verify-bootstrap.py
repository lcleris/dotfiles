#!/usr/bin/env python3
"""Bounded exhaustive check of the install steps in scripts/bootstrap.sh.

Runs the real `bootstrap.sh link cliproxyapi` in a throwaway HOME and a
throwaway copy of the repo, once for every combination of the pre-existing
states in SLOTS, and checks the properties in .claude/skills/verify-bootstrap.

usage: scripts/verify-bootstrap.py [--repo DIR] [--only P1,P3] [-j N]
"""
import argparse
import hashlib
import itertools
import os
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

STEPS = ["link", "cliproxyapi"]
FAKE_USER = "verify-bootstrap-nobody"  # no Keychain entry, so the smudge filter keeps its placeholders
STOW_DEFAULT_IGNORE = re.compile(
    r"^(RCS|.+,v|CVS|\.cvsignore|\.svn|_darcs|\.hg|\.git|\.gitignore|\.gitmodules|.+~|#.*#|\.#.+|README.*|LICENSE.*|COPYING)$"
)


def home_target(rel, home):
    """Where step_link / step_cliproxyapi stow a repo path. None if it is not stowed."""
    p = rel.split("/")
    if p[0] == ".claude":
        return None if len(p) > 1 and p[1] == "skills" else home / rel
    if p[0] == ".config" and len(p) > 1:
        if p[1] == "cli-proxy-api":
            return home.joinpath(".cli-proxy-api", *p[2:])
        return home / rel
    return None


def user_file(rel, content):
    def seed(home, repo):
        f = home / rel
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(content)
        return {rel: content}
    return seed


def link(rel, target):
    def seed(home, repo):
        f = home / rel
        f.parent.mkdir(parents=True, exist_ok=True)
        f.symlink_to(target(home, repo) if callable(target) else target)
        return {}
    return seed


def private_token_dir(home, repo):
    d = home / ".cli-proxy-api"
    d.mkdir(mode=0o755)
    os.chmod(d, 0o755)
    (d / "claude-a.json").write_text("USER oauth token")
    return {".cli-proxy-api/claude-a.json": "USER oauth token"}


absent = None
# One slot per kind of thing step_link / step_cliproxyapi meet on a used Mac.
SLOTS = {
    "config-dir": {
        "absent": absent,
        "foreign-link": link(".config/fish", "/nonexistent/fish"),
        "real-dir": user_file(".config/fish/user-notes.fish", "USER fish notes"),
        "conflict": user_file(".config/fish/config.fish", "USER old config.fish"),
        "plain-file": user_file(".config/fish", "USER file where a dir belongs"),
    },
    "claude-commands": {
        "absent": absent,
        "real-dir": user_file(".claude/commands/my-command.md", "USER command"),
    },
    "claude-settings": {
        "absent": absent,
        "app-created": user_file(".claude/settings.json", '{"written-by": "Claude Code on first launch"}'),
    },
    "cliproxy": {
        "absent": absent,
        "token-dir": private_token_dir,
    },
}


def sh(*cmd, cwd=None, env=None, check=True):
    r = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError(f"{' '.join(cmd)} failed:\n{r.stdout}{r.stderr}")
    return r


def make_template(repo, root):
    """A clean repo copy of the working tree, uncommitted edits included, laid out as ~/dotfiles."""
    tmpl = root / "template"
    head = sh("git", "rev-parse", "HEAD", cwd=repo).stdout.strip()
    sh("git", "clone", "-q", "--no-checkout", str(repo), str(tmpl))
    sh("git", "checkout", "-q", head, cwd=tmpl)
    diff = sh("git", "diff", "HEAD", "--binary", cwd=repo).stdout
    if diff:
        subprocess.run(["git", "apply", "--whitespace=nowarn"], cwd=tmpl, input=diff, text=True, check=True)
    untracked = sh("git", "ls-files", "-o", "--exclude-standard", "-z", cwd=repo).stdout.split("\0")
    for rel in filter(None, untracked):
        (tmpl / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repo / rel, tmpl / rel)
    sh("git", "add", "-A", cwd=tmpl)
    sh("git", "-c", "user.name=v", "-c", "user.email=v@v", "commit", "-q", "--allow-empty", "-m", "snapshot", cwd=tmpl)
    sh("git", "gc", "-q", "--prune=now", cwd=tmpl)
    tracked = sh("git", "ls-files", cwd=tmpl).stdout.split()
    return tmpl, tracked


def env_for(case):
    tools = {Path(shutil.which(t)).parent for t in ("stow", "git", "jq")}
    path = ":".join([str(case / "bin"), *map(str, tools), "/usr/bin", "/bin", "/usr/sbin", "/sbin"])
    return {"HOME": str(case / "home"), "USER": FAKE_USER, "PATH": path,
            "DOTFILES_DIR": str(case / "dotfiles"), "GIT_CONFIG_NOSYSTEM": "1", "LANG": "C"}


def new_case(root, tmpl, name):
    case = root / name
    (case / "home").mkdir(parents=True)
    (case / "prefix" / "etc").mkdir(parents=True)
    (case / "bin").mkdir()
    sh("cp", "-c", "-R", str(tmpl), str(case / "dotfiles"))
    brew = case / "bin" / "brew"
    brew.write_text(f'#!/bin/sh\n[ "$1" = --prefix ] && echo "{case}/prefix" && exit 0\necho "brew $*" >> "{case}/brew.log"\n')
    brew.chmod(0o755)
    return case


def run(case, steps):
    r = subprocess.run(["bash", str(case / "dotfiles/scripts/bootstrap.sh"), *steps],
                       env=env_for(case), capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr)[-1500:]


def sha(p, case=None):
    data = p.read_bytes()
    if case is not None:
        data = data.replace(str(case).encode(), b"CASE")
    return hashlib.sha256(data).hexdigest()[:12]


def snapshot(case):
    home, repo = case / "home", case / "dotfiles"
    out = []
    for p in sorted(home.rglob("*")):
        rel = p.relative_to(home).as_posix()
        if rel == ".dotfiles_bootstrap.log":
            continue
        if p.is_symlink():
            out.append(f"L {rel} -> {os.readlink(p)}")
        elif p.is_dir():
            out.append(f"D {rel} {oct(p.stat().st_mode & 0o777)}")
        else:
            out.append(f"F {rel} {sha(p, case)}")
    conf = case / "prefix/etc/cliproxyapi.conf"
    out.append(f"prefix-conf -> {os.readlink(conf) if conf.is_symlink() else 'missing'}")
    status = sh("git", "status", "--porcelain", "--ignored", "-uall", cwd=repo).stdout.splitlines()
    out += [f"repo {s} {sha(repo / s[3:], case) if (repo / s[3:]).is_file() else '-'}" for s in status]
    out += ["repo-config " + l for l in sh("git", "config", "--local", "--get-regexp", "^filter", cwd=repo, check=False).stdout.splitlines()]
    return sorted(re.sub(r"\.bak\.\d+", ".bak.TIME", line.replace(str(case), "CASE")) for line in out)


def check_state(case, tracked, seeded):
    """P2-P5 on the state one run left behind. Returns a list of violations."""
    home, repo = case / "home", case / "dotfiles"
    bad = []
    real_repo = repo.resolve()
    for rel in tracked:
        dest = home_target(rel, home)
        if dest is None or STOW_DEFAULT_IGNORE.match(Path(rel).name):
            continue
        if dest.resolve() != (repo / rel).resolve():
            bad.append(f"P2 ~/{dest.relative_to(home)} does not resolve to repo {rel}")
    for p in home.rglob("*"):
        if p.is_symlink() and str(p.resolve()).startswith(str(real_repo) + "/"):
            rel = p.resolve().relative_to(real_repo).as_posix()
            if home_target(rel, home) != p:
                bad.append(f"P2 stray link ~/{p.relative_to(home)} -> repo {rel}")
    conf = case / "prefix/etc/cliproxyapi.conf"
    if conf.resolve() != (repo / ".config/cli-proxy-api/config.yaml").resolve():
        bad.append("P2 brew prefix etc/cliproxyapi.conf does not reach the repo config")
    brew_log = case / "brew.log"
    if "brew services start cliproxyapi" not in (brew_log.read_text() if brew_log.exists() else ""):
        bad.append("P2 cliproxyapi brew service never started")
    filters = sh("git", "config", "--local", "--get-regexp", "^filter", cwd=repo, check=False).stdout
    for want in ["filter.claude-settings.clean jq 'del(.autoMode)'",
                 f"filter.cliproxy-secrets.smudge {repo}/scripts/cliproxy-secrets.sh smudge",
                 f"filter.cliproxy-secrets.clean {repo}/scripts/cliproxy-secrets.sh clean"]:
        if want not in filters:
            bad.append(f"P2 git filter missing: {want}")
    for rel, content in seeded.items():
        f = home / rel
        # The file itself, or a .bak copy of it or of a folder holding it.
        kept = [f]
        for a in [f, *f.parents]:
            if a == home:
                break
            if a.parent.is_dir():
                kept += [b / f.relative_to(a) for b in a.parent.glob(a.name + ".bak.*")]
        if not any(k.is_file() and k.read_text() == content for k in kept):
            bad.append(f"P3 user file ~/{rel} lost: not at its path, not adopted, no .bak copy")
    for line in sh("git", "status", "--porcelain", "--ignored", "-uall", cwd=repo).stdout.splitlines():
        code, rel = line[:2], line[3:]
        dest = home_target(rel, home)
        adopted = code == " M" and dest is not None and seeded.get(dest.relative_to(home).as_posix()) == (repo / rel).read_text()
        if not adopted:
            bad.append(f"P4 repo changed by the install: {line}")
    for rel, mode in [(".claude", None), (".cli-proxy-api", 0o700)]:
        d = home / rel
        if d.is_symlink() or not d.is_dir():
            bad.append(f"P5 ~/{rel} is not a real directory")
        elif mode is not None and d.stat().st_mode & 0o777 != mode:
            bad.append(f"P5 ~/{rel} has mode {oct(d.stat().st_mode & 0o777)}, want {oct(mode)}")
    return bad


def check_combo(root, tmpl, tracked, i, combo):
    name = "+".join(f"{s}={v}" for s, v in combo)
    case = new_case(root, tmpl, f"c{i}")
    seeded = {}
    for slot, state in combo:
        seed = SLOTS[slot][state]
        if seed:
            seeded |= seed(case / "home", case / "dotfiles")
    rc, log = run(case, STEPS)
    if rc:
        why = [l.strip() for l in re.sub(r"\x1b\[[0-9;]*m", "", log).splitlines() if l.strip().startswith(("* ", "✗"))]
        return name, [f"P1 install exited {rc}: {(why or log.strip().splitlines() or [''])[0]}"]
    bad = check_state(case, tracked, seeded)
    first = snapshot(case)
    rc, log = run(case, STEPS)
    if rc:
        bad.append(f"P6 second run exited {rc}")
    elif snapshot(case) != first:
        diff = sorted(set(first) ^ set(snapshot(case)))[:4]
        bad.append(f"P6 second run changed the result: {diff}")
    shutil.rmtree(case)
    return name, bad


def check_orders(root, tmpl, tag, combo):
    finals = {}
    for order in itertools.permutations(STEPS):
        case = new_case(root, tmpl, f"o{tag}-" + "-".join(order))
        for slot, state in combo:
            if SLOTS[slot][state]:
                SLOTS[slot][state](case / "home", case / "dotfiles")
        rc, _ = run(case, list(order))
        finals[order] = snapshot(case) if rc == 0 else [f"exit {rc}"]
        shutil.rmtree(case)
    ref = finals[tuple(STEPS)]
    return [f"P7 order {' '.join(o)} ends in a different state: {sorted(set(ref) ^ set(s))[:3]}"
            for o, s in finals.items() if s != ref]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=Path(__file__).resolve().parent.parent, type=Path)
    ap.add_argument("--only", default="", help="comma list of properties to report, e.g. P2,P6")
    ap.add_argument("-j", type=int, default=os.cpu_count() or 2)
    a = ap.parse_args()
    only = set(filter(None, a.only.split(",")))

    root = Path(tempfile.mkdtemp(prefix="verify-bootstrap."))
    try:
        tmpl, tracked = make_template(a.repo.resolve(), root)
        combos = list(itertools.product(*[[(s, v) for v in states] for s, states in SLOTS.items()]))
        with ThreadPoolExecutor(a.j) as pool:
            results = list(pool.map(lambda ic: check_combo(root, tmpl, tracked, *ic), enumerate(combos)))
        installable = tuple((s, "absent") if s in ("config-dir",) else (s, list(v)[-1]) for s, v in SLOTS.items())
        order_bad = check_orders(root, tmpl, "clean", tuple((s, "absent") for s in SLOTS)) + check_orders(root, tmpl, "used", installable)
    finally:
        shutil.rmtree(root, ignore_errors=True)

    by_violation = {}
    for name, bad in results:
        for v in bad:
            by_violation.setdefault(re.sub(r"[0-9a-f]{12}", "…", v), []).append(name)
    for v in order_bad:
        by_violation.setdefault(v, []).append("order check")
    shown = {v: n for v, n in by_violation.items() if not only or v[:2] in only}
    for v, names in sorted(shown.items()):
        print(f"FAIL {v}\n     {len(names)} case(s), e.g. {names[0]}")
    total = len(combos)
    print(f"\n{total} start states x 2 runs, {2 * len(list(itertools.permutations(STEPS)))} step orders. {'FAIL' if shown else 'PASS'}"
          f"{f' ({len(shown)} distinct violations)' if shown else ''}")
    sys.exit(1 if shown else 0)


if __name__ == "__main__":
    main()
