#!/bin/bash
# agent-runbook installer — skills + marked AGENTS.md block.
# Idempotent. Targets stock macOS (bash 3.2, BSD userland) and Linux.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"

# Skills are symlinked, not copied: the repo stays the single source of truth.
# Pull + re-run install to update.
OMP_SKILLS="${HOME}/.omp/agent/skills"
AGENTS_SKILLS="${HOME}/.agents/skills"
OMP_AGENTS="${HOME}/.omp/agent/AGENTS.md"

BEGIN_MARK="<!-- BLOCK:BEGIN:agent-runbook -->"
END_MARK="<!-- BLOCK:END:agent-runbook -->"

SKILL_DIRS="bro-mode eng-playbooks"

installed=""

for base in "$OMP_SKILLS" "$AGENTS_SKILLS"; do
  if mkdir -p "$base" 2>/dev/null; then
    for skill in $SKILL_DIRS; do
      src="$HERE/skills/$skill"
      dst="$base/$skill"
      if [ -L "$dst" ]; then
        rm "$dst"
      elif [ -e "$dst" ]; then
        echo "REFUSED: $dst exists and is not a symlink. Remove it (or move it aside) and re-run." >&2
        exit 1
      fi
      ln -s "$src" "$dst"
      installed="$installed
  $dst -> $src"
    done
  else
    echo "NOTE: $base not writable; skipped."
  fi
done

mkdir -p "$(dirname "$OMP_AGENTS")"

# Extract the block from the repo's AGENTS.md (between the marks, inclusive).
tmp_block="$(mktemp)"
awk -v begin="$BEGIN_MARK" -v end="$END_MARK" '
  $0 == begin { inblock = 1 }
  inblock { print }
  inblock && $0 == end { inblock = 0 }
' "$HERE/AGENTS.md" > "$tmp_block"
if [ ! -s "$tmp_block" ]; then
  echo "REFUSED: no marked block found in $HERE/AGENTS.md" >&2
  rm -f "$tmp_block"
  exit 1
fi
block_lines="$(wc -l < "$tmp_block" | tr -d ' ')"
if [ "$block_lines" -lt 5 ]; then
  echo "REFUSED: marked block in $HERE/AGENTS.md looks truncated ($block_lines lines)" >&2
  rm -f "$tmp_block"
  exit 1
fi

if [ -f "$OMP_AGENTS" ]; then
  # Remove any previous block (awk state machine, portable), then append fresh.
  tmp_out="$(mktemp)"
  awk -v begin="$BEGIN_MARK" -v end="$END_MARK" '
    $0 == begin { skipping = 1 }
    skipping { if ($0 == end) skipping = 0; next }
    { print }
  ' "$OMP_AGENTS" > "$tmp_out"
  mv "$tmp_out" "$OMP_AGENTS"
fi

printf '\n' >> "$OMP_AGENTS"
cat "$tmp_block" >> "$OMP_AGENTS"
rm -f "$tmp_block"
installed="$installed
  $OMP_AGENTS (marked block appended/refreshed)"

cat <<EOF

agent-runbook installed.
$installed

Uninstall: remove the marked block from $OMP_AGENTS and the two symlinks above.
EOF