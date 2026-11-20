# ship-check

A Claude Code skill that checks a project for leaked passwords, API keys and tokens before you publish it. Built for people who make things with AI and are not security engineers.

It started with one finding: when you click "don't ask again" on a command in Claude Code, the whole command is saved to `.claude/settings.local.json`. If you typed a key into that command, the key is in the file. Plenty of people have published that file without knowing.

## What it does

1. Runs a scan of the folder and its git history (`scripts/ship-check.sh`).
2. Explains each finding in plain words and tells you what to do about it.
3. Walks you through four checks a script cannot do: open the app logged out, check your share links, list what your AI agent can write to, and stop approving commands that have passwords in them.

It never prints a secret. You see the file, the line and the first four characters.

## Install

1. Download this repo (Code, then Download ZIP) and unzip it.
2. Move the `ship-check` folder into your Claude Code skills folder: `~/.claude/skills/`
3. Open Claude Code in any project and say: `run a ship check on this folder`

No Claude Code? The script runs on its own:

```bash
bash scripts/ship-check.sh /path/to/your/project
```

It needs bash, grep, awk and find, which every Mac and Linux machine has. git is optional.

## Example

`examples/sample-report.txt` is a real run on a practice folder with made-up keys. It found a saved command with a token in it, a password in a config file, the same password in git history, and a `.env` file that was about to ship.

## What it will not catch

Secrets with unusual shapes, anything inside a hosted database, and anything on a vendor's side. It is a first pass, not an audit. If your project handles customer data or payments, get a professional review.

## If it finds a real key

Rotate it first. Make a new key at the provider and turn the old one off. Clean up the files second. A key that was public for a minute should be treated as stolen.

## License

MIT. Use it, change it, share it.
