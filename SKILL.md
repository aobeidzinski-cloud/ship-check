---
name: ship-check
description: Run before anything you built with AI leaves your laptop. Scans a project folder (and its git history) for passwords, API keys and tokens, including the ones Claude Code saves into .claude/settings.local.json when you click "don't ask again". Then walks through the four checks a script cannot do. Use when the user says ship check, is it safe to publish, check this before I push, make this repo public, or is about to share an app, a repo or a skill.
---

# Ship check

A plain-language safety pass for people who build with AI and are not security engineers. It answers one question: if I publish this folder right now, what goes with it that I did not mean to share?

## When to use it

- Before making a GitHub repo public or pushing to one that already is.
- Before sharing a Claude Code skill, a script or a zip of a project.
- Before publishing an app built with an AI builder.
- After reading a news story about leaked keys and wondering about your own.

## Step 1: run the scan

```bash
bash scripts/ship-check.sh /path/to/the/folder
```

No folder means the current one. It needs bash, grep, awk and find. git is optional. It prints blockers and warnings and never prints a secret value: you see the file, the line and the first four characters.

What it checks:

1. **AI agent settings files.** `.claude/settings.local.json` and `.claude/settings.json` hold every command you approved with "don't ask again", in full. If a command had a password or token typed into it, the file has it too. The scan counts those commands and tells you whether git has ever seen the file.
2. **Secrets in the files you are about to publish.** Common key shapes plus anything that looks like `password = ...` or `token: ...`.
3. **Secrets in git history.** Deleting a key from a file does not delete it from history, and a public repo publishes its whole history.
4. **Files that should never ship.** `.env`, `.pem`, `.key`, credentials files, and whether `.gitignore` covers them.
5. **Things that say more than you meant.** Paths from your computer (they show your username) and email addresses.

Add your own terms, such as a client name, at run time. Do not save them in the script:

```bash
EXTRA_RE='client-name|internal-project' bash scripts/ship-check.sh .
```

Exit code 0 means no blockers, 1 means blockers, 2 means the folder was not found.

## Step 2: read the result with the user

Go through every blocker and warning in plain words. For each one, say what it is, whether it looks real or like a placeholder, and what to do:

- **A real credential, anywhere.** Rotate it first (make a new key at the provider, turn the old one off). Clean up second. A key that was public for a minute should be treated as stolen.
- **A secret in history.** Do not try to fix history in place unless the user knows how. The safe route is a fresh folder with only the current clean files, a new repo, and the old one kept private.
- **A settings file that git tracks.** `git rm --cached .claude/settings.local.json`, add it to `.gitignore`, and delete the rules that hold secrets.
- **A placeholder that looks like a key.** Reword it to plain words such as `PASTE_YOUR_KEY_HERE`. Key-shaped placeholders get uploads blocked by GitHub's push protection.

Never print, repeat or summarize a secret value. Never rotate, delete or commit anything without the user saying yes.

## Step 3: the four checks a script cannot do

Ask the user each one and wait for the answer.

1. **Open it logged out.** If this is a live app, open it in a private window with no login. Click around. Whatever loads for a stranger, the whole internet can read. If the app has a database, ask the AI builder directly: "Which tables can a visitor read without signing in?"
2. **Check every share setting.** "Anyone with the link" means public. That includes the app, the docs it links to, dashboards and file folders.
3. **List what the agent can write to.** For every connector, token or MCP server the project uses: can it only read, or can it also create, edit and delete? Start on read-only. Add write access one tool at a time, when a task needs it.
4. **Approve patterns, not passwords.** When Claude Code asks to run a command with a key typed into it, do not choose "don't ask again". Put the key in an environment variable and approve the command that uses the variable.

## Step 4: give a verdict

End with one of three lines: safe to publish, safe after these fixes (list them), or do not publish yet (say why). Keep it short.

## What this is not

It is a first pass, not an audit. It will miss secrets with unusual shapes and it cannot see inside a hosted database or a vendor's systems. If the project handles customer data, payments or health information, get a professional review.
