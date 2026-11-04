#!/usr/bin/env python3
"""Reports wiki notes that no longer match the code, using git only (no model, no tokens).

python check_wiki.py [--wiki docs/wiki]        run it from inside the repository
Exit code 0 means everything is current, 1 means something needs a look, 2 means it could not run.
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

FRONT = re.compile(r"\A---\r?\n(.*?)\r?\n---", re.S)
LINK = re.compile(r"\]\(([^)#\s]+\.md)\)")


def git(root, *args):
    return subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace")


def parse_front(text):
    """Reads the checked hash and the sources list, written inline or as dash items."""
    match = FRONT.match(text)
    if not match:
        return None, []
    checked, sources, in_list = None, [], False
    for line in match.group(1).splitlines():
        key = re.match(r"(\w+):\s*(.*)", line)
        if key:
            in_list = False
            name, value = key.group(1), key.group(2).strip()
            if name == "checked":
                checked = value.strip("'\"") or None
            elif name == "sources":
                if value.startswith("["):
                    sources = [s.strip().strip("'\"") for s in value.strip("[]").split(",") if s.strip()]
                else:
                    in_list = True
        elif in_list and line.strip().startswith("- "):
            sources.append(line.strip()[2:].strip().strip("'\""))
    return checked, sources


def check_note(root, note):
    """Returns the problems found in one note."""
    checked, sources = parse_front(note.read_text(encoding="utf-8", errors="replace"))
    if not sources or not checked:
        return ["no sources or checked field, so it cannot be tracked"]
    if git(root, "rev-parse", "--verify", "--quiet", checked + "^{commit}").returncode != 0:
        return ["checked commit %s is not in this repository" % checked]
    problems = []
    for src in sources:
        # A source can be a file, a folder or a git pathspec such as models/*.py.
        if not (root / src).exists() and not git(root, "ls-files", "--", src).stdout.strip():
            problems.append("source is gone: %s" % src)
            continue
        commits = git(root, "rev-list", "--count", checked + "..HEAD", "--", src).stdout.strip()
        if commits and commits != "0":
            problems.append("%s changed in %s commit(s)" % (src, commits))
        elif git(root, "diff", "--quiet", "HEAD", "--", src).returncode != 0:
            problems.append("%s has uncommitted changes" % src)
    return problems


def check_index(wiki, notes):
    """Compares the links in INDEX.md with the notes on disk."""
    index = wiki / "INDEX.md"
    if not index.exists():
        return ["INDEX.md is missing"]
    text = index.read_text(encoding="utf-8", errors="replace")
    linked = set(LINK.findall(text))
    problems = ["INDEX.md links to a missing note: %s" % link for link in sorted(linked) if not (wiki / link).exists()]
    problems += ["not listed in INDEX.md: %s" % n.relative_to(wiki).as_posix() for n in notes if n.relative_to(wiki).as_posix() not in linked]
    todo = len(re.findall(r"\|\s*todo\s*\|\s*$", text, re.M))
    if todo:
        problems.append("%d area(s) still marked todo: run document-repo again to finish them" % todo)
    return problems


def main():
    ap = argparse.ArgumentParser(description="Report wiki notes that no longer match the code.")
    ap.add_argument("--wiki", default="docs/wiki", help="wiki folder, relative to the repository root")
    args = ap.parse_args()
    top = git(Path.cwd(), "rev-parse", "--show-toplevel")
    if top.returncode != 0:
        print("Not inside a git repository.")
        return 2
    root = Path(top.stdout.strip())
    wiki = root / args.wiki
    if not wiki.is_dir():
        print("No wiki at %s." % wiki)
        return 2
    notes = sorted(p for p in wiki.rglob("*.md") if p.name != "INDEX.md")
    found = 0
    for note in notes:
        problems = check_note(root, note)
        if problems:
            found += 1
            print("STALE %s" % note.relative_to(root).as_posix())
            for problem in problems:
                print("  %s" % problem)
    index_problems = check_index(wiki, notes)
    for problem in index_problems:
        print("INDEX %s" % problem)
    print("%d note(s) checked, %d stale, %d index problem(s)." % (len(notes), found, len(index_problems)))
    return 1 if found or index_problems else 0


if __name__ == "__main__":
    sys.exit(main())
