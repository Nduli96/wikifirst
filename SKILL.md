---
name: wikifirst
description: Look in the repository's wiki before searching its code, and write down what was hard to find so no session has to find it twice. Use for /wikifirst, at the start of a task that needs to know how part of the repository works, and after work that took long to figure out. Stays on for the session.
---

# wikifirst

Do not search for what is already known. Do not make the next session search for what you just learned.

The wiki is `docs/wiki/`. `INDEX.md` lists its notes. If it does not exist, say so once in one line and work normally. If the project's own instructions say where documentation lives or when to write it, they win over this skill.

## Before searching the code

1. A file, symbol or distinctive term you can search for: search for it directly. There the wiki adds cost. It is for what you do not know how to find, and for what the code does not say.
2. Otherwise read `docs/wiki/INDEX.md`, once per session.
3. One note matches: read it, only the section you need.
4. The question spans several notes, or the index does not settle it: ask the `wiki-search` subagent if it is installed. It returns the answer without filling this session's context.
5. Nothing matches: search the code normally.

A note tells you where to look and what to expect. **The code wins.** Confirm any fact you are about to act on. If a note is wrong, fix it in the same turn. To see which notes have gone stale, run this skill's `check_wiki.py` from inside the repository.

## After the work

Write a note, or update the one that exists, only when finding this again would cost more than writing it:

- a flow across several files that took many searches to follow;
- a cause that was not where the problem appeared;
- an order, value or limit that looks wrong and is not;
- what to change, and where, to do a recurring job.

Say so in one line before writing. Do not write what one search finds, what the code says plainly, or what `git log` already records.

Never write passwords, keys, tokens, personal data or private server addresses. Name the setting or file that holds them instead.

## Note format

One topic per note, under 60 lines, in `docs/wiki/<topic>.md`:

```markdown
---
sources: [path/to/first_file.py, path/to/second_file.py]
checked: <output of git rev-parse --short HEAD>
---
# Topic

What it does, in one line.

## Flow
## Constraints and traps
## Where to change what
```

`sources` lists the files the note describes, with paths from the repository root. Update `checked` whenever you confirm the note against the code. Then add or correct its row in `INDEX.md`:

```markdown
| Area | Note | Answers |
|---|---|---|
| Payments | [checkout](checkout.md) | How the total is computed, and where rounding happens |
```
