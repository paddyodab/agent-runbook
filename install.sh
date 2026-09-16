#!/bin/bash
# agent-runbook installer — skills + marked AGENTS.md block + scaffold.
# Idempotent. Targets stock macOS (bash 3.2, BSD userland) and Linux.
#
# Usage:
#   install.sh                classic mode: install from the working tree (dev box)
#   install.sh --machine      machine mode: driven by machine.yml (fresh box / VPS / sandbox);
#                             version checks, adapter selection, secrets gated never written
#   install.sh --doctor       doctor mode: report what's missing/drifted, change nothing
#   install.sh --adapter X    machine-mode override: activate adapter X from machine.yml
#                            (none|gh-issues|shortcut); default comes from machine.yml
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"

MODE="classic"
ADAPTER_OVERRIDE=""
DOCTOR="0"
while [ $# -gt 0 ]; do
  case "$1" in
    --machine) MODE="machine"; shift ;;
    --doctor) DOCTOR="1"; shift ;;
    --adapter)
      if [ $# -lt 2 ]; then echo "--adapter requires a value (none|gh-issues|shortcut)" >&2; exit 1; fi
      ADAPTER_OVERRIDE="$2"; shift 2 ;;
    --adapter=*) ADAPTER_OVERRIDE="${1#--adapter=}"; shift ;;
    *) echo "Unknown argument: $1 (usage: install.sh [--machine] [--doctor] [--adapter X])" >&2; exit 1 ;;
  esac
done

# Skills are symlinked, not copied: the repo stays the single source of truth.
# Machine mode reads the list from machine.yml; classic mode uses the hardcoded set.
OMP_SKILLS="${HOME}/.omp/agent/skills"
AGENTS_SKILLS="${HOME}/.agents/skills"
OMP_AGENTS="${HOME}/.omp/agent/AGENTS.md"

BEGIN_MARK="<!-- BLOCK:BEGIN:agent-runbook -->"
END_MARK="<!-- BLOCK:END:agent-runbook -->"

SKILL_DIRS="bro-mode eng-playbooks fan-out-lanes turborepo"
MANIFEST="$HERE/machine.yml"

if [ "$MODE" = "machine" ]; then
  if [ ! -f "$MANIFEST" ]; then
    echo "REFUSED: machine mode needs machine.yml next to install.sh; not found." >&2
    exit 1
  fi
  # bash-3.2-safe manifest parse: plain awk over the skills: block.
  MANIFEST_SKILLS="$(awk '
    /^skills:/ { inskills = 1; next }
    inskills && /^[a-z_]+:/ { inskills = 0 }
    inskills && /^  - name:/ { sub(/^  - name: */, ""); gsub(/ *#.*/, ""); gsub(/"/, ""); name = $0 }
    inskills && /^    source:/ { sub(/^    source: */, ""); gsub(/ *#.*/, ""); gsub(/"/, ""); print name " " $0 }
  ' "$MANIFEST")"
  if [ -z "$MANIFEST_SKILLS" ]; then
    echo "REFUSED: machine.yml skills: block parsed empty — manifest format drift." >&2
    exit 1
  fi
  SKILL_DIRS="$(printf '%s\n' "$MANIFEST_SKILLS" | awk '{ printf "%s%s", (NR>1?" ":""), $1 }')"
  ACTIVE_ADAPTER="${ACTIVE_ADAPTER:-none}"
  if [ -n "$ADAPTER_OVERRIDE" ]; then
    case "$ADAPTER_OVERRIDE" in
      none|gh-issues|shortcut) ACTIVE_ADAPTER="$ADAPTER_OVERRIDE" ;;
      *) echo "REFUSED: unknown adapter '$ADAPTER_OVERRIDE' (none|gh-issues|shortcut)" >&2; exit 1 ;;
    esac
  fi
fi

SCAFFOLD_SRC="$HERE/scaffold/new-enclosing-folder.sh"
SCAFFOLD_DST="${HOME}/.local/bin/new-enclosing-folder.sh"

installed=""
warn=""

# 0. Machine mode: omp version check + runtime deps + adapter + secrets gates.
if [ "$MODE" = "machine" ]; then
  # omp binary present + version pin check (warn, never auto-change).
  if command -v omp >/dev/null 2>&1; then
    OMP_VER="$(omp --version 2>/dev/null | head -1 | awk -F/ '{print $2}')"
    OMP_PIN="$(awk '/^    version: "/ { sub(/^    version: */, ""); gsub(/ *#.*/, ""); gsub(/"/, ""); print; exit }' "$MANIFEST")"
    if [ -n "$OMP_PIN" ] && [ "$OMP_VER" != "$OMP_PIN" ]; then
      warn="$warn
  omp version $OMP_VER != machine.yml pin $OMP_PIN (pin is advisory; reconcile deliberately)"
    fi
  else
    warn="$warn
  omp binary not on PATH — install it first (see machine.yml omp.install_hint)"
  fi

  # Runtime deps from manifest: name + check pairs in the runtime_deps: block.
  DEPS_BLOCK="$(awk '
    /^  runtime_deps:/ { indeps = 1; next }
    indeps && /^  [a-z_]+:/ { indeps = 0 }
    indeps && /^    - name:/ { sub(/^    - name: */, ""); gsub(/ *#.*/, ""); gsub(/"/, ""); name = $0 }
    indeps && /^      check:/ { sub(/^      check: */, ""); gsub(/ *#.*/, ""); print name "\t" $0 }
  ' "$MANIFEST")"
  OPTIONAL_DEPS="$(awk '
    /^  runtime_deps:/ { indeps = 1; next }
    indeps && /^  [a-z_]+:/ { indeps = 0 }
    indeps && /^    - name:/ { sub(/^    - name: */, ""); gsub(/ *#.*/, ""); gsub(/"/, ""); name = $0 }
    indeps && /^      optional: true/ { print name }
  ' "$MANIFEST")"
  while IFS="$(printf '\t')" read -r dname dcheck; do
    [ -z "$dname" ] && continue
    if sh -c "$dcheck" >/dev/null 2>&1; then
      : # present
    else
      is_opt="0"
      for od in $OPTIONAL_DEPS; do [ "$od" = "$dname" ] && is_opt="1"; done
      if [ "$is_opt" = "1" ]; then
        warn="$warn
  optional dep missing: $dname (some extras degrade gracefully)"
      else
        echo "REFUSED: required runtime dep missing: $dname (check: $dcheck)" >&2
        echo "  Install it, then re-run. machine.yml lists every dep with its check." >&2
        exit 1
      fi
    fi
  done <<EOF2
$DEPS_BLOCK
EOF2
fi


if [ "$DOCTOR" != "1" ]; then
# 1. Skills (symlinks; replaced atomically on rerun)
for base in "$OMP_SKILLS" "$AGENTS_SKILLS"; do
  if mkdir -p "$base" 2>/dev/null; then
    for skill in $SKILL_DIRS; do
      src="$HERE/skills/$skill"
      dst="$base/$skill"
      if [ -L "$dst" ]; then
        rm "$dst"
      elif [ -e "$dst" ]; then
        if [ -d "$dst" ]; then
          echo "NOTE: $dst is a real directory (older copied skill). Moving aside to $dst.pre-runbook; re-run to replace with symlink."
          mv "$dst" "$dst.pre-runbook"
        else
          echo "REFUSED: $dst exists and is not a symlink. Remove it (or move it aside) and re-run." >&2
          exit 1
        fi
      fi
      ln -s "$src" "$dst"
      installed="$installed
  $dst -> $src"
    done
  else
    echo "NOTE: $base not writable; skipped."
  fi
done
fi

if [ "$DOCTOR" != "1" ]; then
# 2. AGENTS.md marked block (extracted from this repo's AGENTS.md — never embedded)
mkdir -p "$(dirname "$OMP_AGENTS")"

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
fi

# 3. Scaffold (copy, exec bit — only if ~/.local/bin exists and is on PATH;
#    refuse to clobber a foreign file, replace our own prior install atomically)
if [ "$DOCTOR" != "1" ] && [ -x "$SCAFFOLD_SRC" ] && [ -d "${HOME}/.local/bin" ]; then
  case ":$PATH:" in
    *":${HOME}/.local/bin:"*)
      if [ -L "$SCAFFOLD_DST" ]; then
        rm "$SCAFFOLD_DST"
      elif [ -e "$SCAFFOLD_DST" ]; then
        if cmp -s "$SCAFFOLD_DST" "$SCAFFOLD_SRC"; then
          : # same content; refresh below
        else
          echo "REFUSED: $SCAFFOLD_DST exists and differs from this repo's copy." >&2
          echo "  If it is your own customization: diff it against scaffold/new-enclosing-folder.sh," >&2
          echo "  reconcile, then re-run. Refusing to overwrite." >&2
          exit 1
        fi
      fi
      tmp_cp="$(mktemp)"
      cat "$SCAFFOLD_SRC" > "$tmp_cp"
      chmod 755 "$tmp_cp"
      mv "$tmp_cp" "$SCAFFOLD_DST"
      installed="$installed
  $SCAFFOLD_DST (scaffold installed)"
      ;;
    *)
      echo "NOTE: ~/.local/bin exists but is not on PATH; scaffold not installed."
      ;;
  esac
fi

# 4. Adapter (machine mode): ticketing integration per machine.yml.
if [ "$MODE" = "machine" ] && [ "$ACTIVE_ADAPTER" != "none" ]; then
  ADAPTER_REPO="$(awk -v a="$ACTIVE_ADAPTER" '
    $0 == "    " a ":" { ina = 1; next }
    ina && /^    [a-z-]+:/ { ina = 0 }
    ina && /^      repo:/ { sub(/^      repo: */, ""); gsub(/"/, ""); print }
  ' "$MANIFEST")"
  ADAPTER_PIN="$(awk -v a="$ACTIVE_ADAPTER" '
    $0 == "    " a ":" { ina = 1; next }
    ina && /^    [a-z-]+:/ { ina = 0 }
    ina && /^      pin:/ { sub(/^      pin: */, ""); gsub(/ *#.*/, ""); gsub(/"/, ""); print }
  ' "$MANIFEST")"
  if [ -n "$ADAPTER_REPO" ]; then
    ADAPTER_DIR="${HOME}/.omp/adapters/${ACTIVE_ADAPTER}"
    if [ -d "$ADAPTER_DIR/.git" ]; then
      CUR="$(git -C "$ADAPTER_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
      if [ "$CUR" != "$ADAPTER_PIN" ]; then
        warn="$warn
  adapter $ACTIVE_ADAPTER at $CUR != pin $ADAPTER_PIN (re-clone deliberately to move)"
      fi
    elif [ "$DOCTOR" != "1" ]; then
      mkdir -p "$(dirname "$ADAPTER_DIR")"
      git clone "$ADAPTER_REPO" "$ADAPTER_DIR" >/dev/null 2>&1
      git -C "$ADAPTER_DIR" checkout --quiet "$ADAPTER_PIN" 2>/dev/null || warn="$warn
  adapter pin $ADAPTER_PIN not found in $ADAPTER_REPO — check machine.yml"
      installed="$installed
  $ADAPTER_DIR (cloned @ $(git -C "$ADAPTER_DIR" rev-parse --short HEAD 2>/dev/null || echo '?'))"
    fi
    if [ "$DOCTOR" != "1" ] && command -v omp >/dev/null 2>&1; then
      if omp plugin list 2>/dev/null | grep -q "$ACTIVE_ADAPTER"; then
        : # already linked
      else
        if omp plugin link "$ADAPTER_DIR" >/dev/null 2>&1; then
          installed="$installed
  omp extension linked: $ACTIVE_ADAPTER"
        else
          warn="$warn
  omp plugin link failed for $ADAPTER_DIR (run manually: omp plugin link $ADAPTER_DIR)"
        fi
      fi
    fi
  fi

  # Secrets: gate presence, never write values (secrets_policy: manual-interactive).
  # Pairs (name,check) then hint lines; a missing secret collects its hint.
  SECRETS_BLOCK="$(awk -v a="$ACTIVE_ADAPTER" '
    $0 == "    " a ":" { ina = 1; next }
    ina && /^    [a-z-]+:/ { ina = 0 }
    ina && /^        - name:/ { sub(/^        - name: */, ""); gsub(/"/, ""); name = $0 }
    ina && /^          check:/ { sub(/^          check: */, ""); print "SEC\t" name "\t" $0 }
    ina && /^          hint:/ { sub(/^          hint: */, ""); print "HINT\t" name "\t" $0 }
  ' "$MANIFEST")"
  LAST_NAME=""; LAST_PENDING="0"
  while IFS="$(printf '\t')" read -r kind sname sval; do
    [ -z "$kind" ] && continue
    if [ "$kind" = "SEC" ]; then
      LAST_NAME="$sname"
      if sh -c "$sval" >/dev/null 2>&1; then
        LAST_PENDING="0"
      else
        LAST_PENDING="1"
        warn="$warn
  secret missing: $sname (set it, then re-run for a clean doctor bill)"
      fi
    elif [ "$kind" = "HINT" ] && [ "$LAST_PENDING" = "1" ] && [ "$sname" = "$LAST_NAME" ]; then
      warn="$warn
    how: $sval"
    fi
  done <<EOF3
$SECRETS_BLOCK
EOF3
fi

# Doctor gate: after every check/parse, before any mutation. Report + exit 0.
if [ "$DOCTOR" = "1" ]; then
  echo "doctor report ($MODE mode):"
  if [ -n "$warn" ]; then
    printf '%s\n' "$warn" | sed 's/^/  /'
  else
    echo "  nothing missing, nothing drifted"
  fi
  exit 0
fi

cat <<EOF

agent-runbook installed ($MODE mode).
$installed
${warn:+
WARNINGS:
$warn
}
Uninstall: remove the marked block from $OMP_AGENTS, the skill symlinks under
$OMP_SKILLS and $AGENTS_SKILLS, $SCAFFOLD_DST if it was installed,
and any adapter clone under ~/.omp/adapters/.
EOF