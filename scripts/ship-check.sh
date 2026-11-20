#!/bin/bash
# ship-check: look for secrets and loose ends before a folder goes public.
# Usage:  bash ship-check.sh [folder]      (defaults to the current folder)
# Exit:   0 = no blockers, 1 = blockers found, 2 = bad usage
# Needs:  bash, grep, awk, find. git is optional (history checks are skipped without it).
# Secret values are never printed. You see the file, the line, and the first 4 characters.

DIR="${1:-.}"
if [ "$DIR" = "-h" ] || [ "$DIR" = "--help" ]; then sed -n '2,6p' "$0"; exit 0; fi
[ -d "$DIR" ] || { echo "Not a folder: $DIR"; exit 2; }
cd "$DIR" || exit 2

BLOCK=0; WARN=0
blocker() { BLOCK=$((BLOCK+1)); echo "  BLOCKER  $1"; }
warning() { WARN=$((WARN+1));  echo "  warning  $1"; }
ok()      { echo "  ok       $1"; }

# Shapes that look like real credentials. Add your own with EXTRA_RE='pattern'.
SECRET_RE='(sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{12,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|BEGIN [A-Z ]*PRIVATE KEY|(api[_-]?key|token|secret|password|passwd)[[:space:]]*[=:][[:space:]]*["'"'"']?[A-Za-z0-9._-]{12,})'
[ -n "$EXTRA_RE" ] && SECRET_RE="($SECRET_RE|$EXTRA_RE)"

IS_GIT=0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && IS_GIT=1

list_files() {
  if [ "$IS_GIT" = 1 ]; then git ls-files
  else find . -type f -not -path './.git/*' -not -path '*/node_modules/*' -not -path '*/.venv/*' | sed 's#^\./##'
  fi
}

mask() { # stdin: "line:match"  ->  "file:line  abcd**** (N chars)"
  awk -v f="$1" '{ n=index($0,":"); line=substr($0,1,n-1); m=substr($0,n+1);
       printf "           %s:%s  %s**** (%d chars)\n", f, line, substr(m,1,4), length(m) }'
}

echo "ship-check on: $(pwd)"
[ "$IS_GIT" = 1 ] && echo "git repo: yes (files tracked by git, plus full history)" || echo "git repo: no (every file in the folder, no history)"
echo

echo "1. AI agent settings files (saved 'don't ask again' approvals)"
FOUND_SETTINGS=0
for f in $(find . -path '*/.claude/settings*.json' -not -path './.git/*' -not -path '*/node_modules/*' 2>/dev/null | sed 's#^\./##'); do
  FOUND_SETTINGS=1
  hits=$(grep -ciE "$SECRET_RE" "$f" 2>/dev/null); hits=${hits:-0}
  tracked=0; committed=0; ignored=0
  if [ "$IS_GIT" = 1 ]; then
    git ls-files --error-unmatch "$f" >/dev/null 2>&1 && tracked=1
    committed=$(git log --all --oneline -- "$f" 2>/dev/null | wc -l | tr -d ' ')
    git check-ignore -q "$f" 2>/dev/null && ignored=1
  fi
  if [ "$hits" -gt 0 ] && { [ "$tracked" = 1 ] || [ "$committed" -gt 0 ]; }; then
    blocker "$f has $hits saved command(s) with a secret in them, and git has the file. Rotate those credentials first, then remove the file from git."
  elif [ "$hits" -gt 0 ]; then
    warning "$f has $hits saved command(s) with a secret in plain text. Not in git, but delete those rules and rotate anything you are unsure about."
  elif [ "$tracked" = 1 ] && [ "${f##*/}" = "settings.local.json" ]; then
    warning "$f is tracked by git. It is a personal file. Run: git rm --cached \"$f\""
  else
    ok "$f has no secret-shaped commands"
  fi
  if [ "$IS_GIT" = 1 ] && [ "$ignored" = 0 ] && [ "${f##*/}" = "settings.local.json" ]; then
    warning "$f is not in .gitignore. Add the line: .claude/settings.local.json"
  fi
done
[ "$FOUND_SETTINGS" = 0 ] && ok "no .claude settings files in this folder"
echo

echo "2. Secrets in the files you are about to publish"
N=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in *ship-check.sh|*.png|*.jpg|*.jpeg|*.gif|*.pdf|*.zip|*.mp4|*.lock) continue;; esac
  case "$f" in *.claude/settings*.json) continue;; esac
  out=$(grep -InoiE "$SECRET_RE" -- "$f" 2>/dev/null)
  if [ -n "$out" ]; then echo "$out" | mask "$f"; N=$((N + $(echo "$out" | wc -l | tr -d ' '))); fi
done <<LIST
$(list_files)
LIST
if [ "$N" -gt 0 ]; then blocker "$N secret-shaped string(s) in the files above. Check each one. Real ones get rotated, placeholders get reworded."
else ok "nothing secret-shaped in the files"; fi
echo

echo "3. Secrets in git history (deleted is not gone)"
if [ "$IS_GIT" = 1 ]; then
  H=$(git log --all -i --format='%h' -G"$SECRET_RE" 2>/dev/null | sort -u | wc -l | tr -d ' ')
  if [ "$H" -gt 0 ]; then
    git log --all --format='           commit %h  %ad  %s' --date=short -i -G"$SECRET_RE" 2>/dev/null | cut -c1-110 | head -15
    blocker "$H commit(s) added or removed a secret-shaped string. A public repo publishes all of them. Rotate, then publish from a fresh copy with clean history."
  else ok "no secret-shaped strings in any commit"; fi
else
  echo "  skipped  not a git repo"
fi
echo

echo "4. Files that should never ship"
T=0
while IFS= read -r f; do
  case "${f##*/}" in
    .env.example|.env.sample|.env.template) ;;
    .env|.env.*|*.pem|*.key|*credentials*.json|*secret*.json) T=$((T+1)); echo "           $f";;
  esac
done <<LIST
$(list_files)
LIST
if [ "$T" -gt 0 ]; then blocker "$T file(s) above are key or env files. Remove them from what you publish."
else ok "no .env, .pem, .key or credentials files in what you publish"; fi
if [ "$IS_GIT" = 1 ]; then
  if grep -qE '^\.env' .gitignore 2>/dev/null; then ok ".gitignore covers .env"; else warning ".gitignore does not cover .env. Add the line: .env"; fi
fi
echo

echo "5. Things that say more about you than you meant"
P=$(list_files | while IFS= read -r f; do [ -f "$f" ] && grep -IlE '(/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/|C:\\Users\\)' -- "$f" 2>/dev/null; done | grep -v 'ship-check.sh' | head -20)
if [ -n "$P" ]; then echo "$P" | sed 's/^/           /'; warning "the file(s) above contain a path from your computer (your username and folder names)."
else ok "no local computer paths"; fi
E=$(list_files | while IFS= read -r f; do [ -f "$f" ] && grep -IlE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' -- "$f" 2>/dev/null; done | xargs grep -IhoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' 2>/dev/null | grep -viE '(example\.(com|org)|noreply|@2x|\.png|\.jpg)' | sort -u | wc -l | tr -d ' ')
if [ "${E:-0}" -gt 0 ]; then warning "$E distinct email address(es) in the files. Make sure each one is meant to be public."
else ok "no email addresses"; fi
echo

echo "Result: $BLOCK blocker(s), $WARN warning(s)"
echo
echo "The script cannot check these. You have to:"
echo "  - Open the live app in a private window, logged out. Whatever loads, the internet can read."
echo "  - Look at the share setting on every app, doc and dashboard. 'Anyone with the link' is public."
echo "  - List what your AI agent can write to. Start on read-only and add write access one tool at a time."
echo "  - If a real key shows up above: rotate it first, clean up second."
[ "$BLOCK" -gt 0 ] && exit 1
exit 0
