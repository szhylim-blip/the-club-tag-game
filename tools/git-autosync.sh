#!/usr/bin/env bash
# Keep this working copy and GitHub's main branch in sync.
#
# It commits local workspace edits, rebases them on remote work, pushes, and
# fast-forwards the local tree when the branch is clean and GitHub is ahead.
# Run from the project root: bash tools/git-autosync.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

INTERVAL="${AUTOSYNC_INTERVAL:-8}"
REMOTE_INTERVAL="${AUTOSYNC_REMOTE_INTERVAL:-45}"
BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
LOG="$ROOT/.git/autosync.log"
LAST_REMOTE_CHECK=0

if [ -z "$BRANCH" ]; then
  echo "Autosync needs a checked-out branch." >&2
  exit 1
fi

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"
}

on_exit() {
  log "autosync stopped"
  exit 0
}
trap on_exit INT TERM

log "autosync started for $BRANCH (local every ${INTERVAL}s, remote every ${REMOTE_INTERVAL}s)"

while true; do
  # Commit local workspace changes after a short settling delay so multi-file
  # saves are captured in one commit instead of several partial ones.
  if ! git diff --quiet --ignore-submodules -- ||
     ! git diff --cached --quiet --ignore-submodules -- ||
     [ -n "$(git ls-files --others --exclude-standard)" ]; then
    sleep 3
    git add -A
    if ! git diff --cached --quiet; then
      if git commit -m "chore: autosync workspace edits ($(date '+%Y-%m-%d %H:%M:%S'))" >>"$LOG" 2>&1; then
        log "committed $(git rev-parse --short HEAD)"
      else
        log "commit failed; leaving changes in the working tree"
      fi
    fi
  fi

  # Push any local commits, including ones left over from a failed network run.
  AHEAD="$(git rev-list --count "origin/$BRANCH..$BRANCH" 2>/dev/null || echo 1)"
  if [ "$AHEAD" -gt 0 ] 2>/dev/null; then
    if git pull --rebase --autostash origin "$BRANCH" >>"$LOG" 2>&1; then
      if git push origin "$BRANCH" >>"$LOG" 2>&1; then
        log "pushed $(git rev-parse --short HEAD) to origin/$BRANCH"
      else
        log "push failed; will retry"
      fi
    else
      log "remote pull/rebase failed; resolve the conflict, then autosync will retry"
      git rebase --abort >/dev/null 2>&1 || true
    fi
  fi

  # Pull other editors' GitHub changes, but only when the local tree is clean
  # and there is nothing local waiting to push.
  NOW="$(date +%s)"
  if [ "$AHEAD" -eq 0 ] &&
     git diff --quiet --ignore-submodules -- &&
     git diff --cached --quiet --ignore-submodules -- &&
     [ -z "$(git ls-files --others --exclude-standard)" ] &&
     [ $((NOW - LAST_REMOTE_CHECK)) -ge "$REMOTE_INTERVAL" ]; then
    LAST_REMOTE_CHECK="$NOW"
    if git fetch --quiet origin "$BRANCH" >>"$LOG" 2>&1; then
      if ! git merge-base --is-ancestor "origin/$BRANCH" "$BRANCH"; then
        if git merge --ff-only "origin/$BRANCH" >>"$LOG" 2>&1; then
          log "fast-forwarded local $BRANCH from GitHub"
        else
          log "local fast-forward failed; manual merge needed"
        fi
      fi
    fi
  fi

  sleep "$INTERVAL"
done
