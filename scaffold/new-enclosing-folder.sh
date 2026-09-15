#!/usr/bin/env bash
# new-enclosing-folder.sh — scaffold a bounded-context "enclosing folder":
# a non-git workspace grouping comms/ + sample repos + built repos for one idea.
# Lives on PATH. Run once per new idea.
set -euo pipefail

read -rp "Enclosing folder name (slug, e.g. git-backed-notes): " FOLDER
FOLDER="${FOLDER//[[:space:]]/}"
[[ -z "$FOLDER" || "$FOLDER" == *"/"* ]] && { echo "error: name must be a non-empty slug with no slashes" >&2; exit 1; }

read -rp "One-sentence purpose of this folder: " PURPOSE
[[ -z "$PURPOSE" ]] && { echo "error: purpose is required" >&2; exit 1; }

read -rp "Create under which parent dir? (default: $(pwd)): " PARENT
PARENT="${PARENT:-$(pwd)}"; PARENT="${PARENT/#\~/$HOME}"

TARGET_REAL="$PARENT/$FOLDER"
[[ -e "$TARGET_REAL" ]] && { echo "error: $TARGET_REAL already exists — refusing to clobber" >&2; exit 1; }

# Build atomically: stage everything, move into place only when complete, so a failure
# midway cannot leave a half-built folder. Portable: no in-place sed; works with stock
# bash 3.2 / BSD sed (macOS) — the scaffolded session scripts are also bash-3.2-safe.
STAGE="$PARENT/.$FOLDER.scaffold-$$"
mkdir -p "$STAGE/comms/templates" "$STAGE/prior-art" "$STAGE/artifacts"
TARGET="$STAGE"   # heredocs below write into the staging dir
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

# static "Folder convention" code block (prior-art / built repos are added later, not at scaffold time)
CONVENTION=$'  README.md              <- this file: the folder\'s purpose + conventions\n  comms/                 <- agent/operator conversations and session handoffs (see comms/README.md)\n  artifacts/             <- project-scoped reference material (PDFs, decks, dumps, downloads). Named-by-hand access only: never globbed, never auto-read, never in a reading manifest unless a handoff names the exact file.\n  prior-art/             <- repos we are studying and using for examples (their code; their own git). Read only when directed. Clones here are made read-only: reference, never a work target.\n  <built-repo>/          <- a repo we generate from this work (our code; tracked in git). Created later, once we start building.'

finish() {
  # slug substitution (portable: no in-place sed), exec bits, then the atomic move
  # into place — all inside the staging dir, so an aborted scaffold leaves nothing
  sed "1s/<folder-slug>/$FOLDER/" "$STAGE/AGENTS.md" > "$STAGE/AGENTS.md.tmp" && mv "$STAGE/AGENTS.md.tmp" "$STAGE/AGENTS.md"
  chmod +x "$STAGE/comms/session-start.sh" "$STAGE/comms/session-end.sh"
  mv "$STAGE" "$TARGET_REAL"
}

cat > "$TARGET/README.md" <<EOF
# $FOLDER/

$PURPOSE

This is an **enclosing folder**, not a git repository: it is not checked in. Only the
repositories generated within it are tracked in git.

## Folder convention

\`\`\`
$FOLDER/
$CONVENTION
\`\`\`

## What's checked in

- The enclosing folder (\`$FOLDER/\`) is **not** a git repo.
- \`comms/\` holds plain conversation/handoff files — **not** git-tracked. History lives on disk.
- \`prior-art/\` holds other people's repos, cloned as-is with their own \`.git\`; we read them only when directed, and never commit to them. Clones are made **read-only** on arrival (\`chmod -R a-w\`) — a prior-art repo is reference, never a work target. The copy we work on (if ever) is a separate clone at the folder root.
- \`artifacts/\` holds project-scoped reference material (customer PDFs, decks, exports). It is **not** agent-browsable: open an artifact only when the operator or a handoff names it.
- Repos we generate are git repos and **are** checked in.

## How the agent should interact

1. Read this \`README.md\` first for the purpose and conventions of this folder.
2. Run \`./comms/session-start.sh\` (from this folder root) — it prints the reading manifest:
   \`comms/README.md\` then the newest **sealed** \`comms/<YYYYMMDD>-<NN>/session-handoff.md\`.
   Those are the only comms files to read at session start. The newest sealed handoff is canonical state.
4. \`prior-art/\` is reference material. Read a file from it **only** when a handoff, conversation, or the operator directs you to that specific file — do not scan or index prior-art by default. Prior-art clones are read-only: if a write there is needed, stop and ask; the work copy lives at the folder root.
5. \`artifacts/\` is reference material the operator dropped or directed. Same access rule: named files only, never a directory scan. It is not comms history and not prior-art — it is source material for the work.
6. Work lands in the built repo(s); conversation/handoffs land in \`comms/\`. Don't commit \`prior-art/\`, \`artifacts/\`, or \`comms/\`.
7. Do not edit past handoffs in place — write a new one in the new session's folder so state stays traceable. \`session-end.sh\` seals.
8. To start a new, unrelated idea, make a new enclosing folder (run \`new-enclosing-folder.sh\`).

## This folder
- Prior-art repos are cloned into \`prior-art/\` as needed and made read-only on arrival; repos we build are created at the root later, once study and conversation justify it. Reference material (PDFs, decks) lands in \`artifacts/\`, not comms.
- Multi-agent parallel work happens in git worktrees of a built repo (\`git worktree add ../<repo>-lane-N\` from the built repo), not by writing into prior-art clones.
- Session lifecycle: \`./comms/session-start.sh\` to begin or resume (\`--resume\` for same-day continuation), \`./comms/session-end.sh\` to seal the handoff at session end.
EOF

cat > "$TARGET/comms/README.md" <<'PROTOCOL'
# comms/

The communication and continuity layer of this enclosing folder. This is where
conversations live, where context files get dropped, and the running state of
the work is handed off between sessions.

## The protocol (mechanical, not doctrinal)

Two scripts run the session lifecycle. The convention is what the scripts enforce — not
prose an agent is trusted to remember.

```text
operator / agent          what happens
------------------------  -----------------------------------------------------------
./comms/session-start.sh  finds the newest SEALED handoff (canonical state),
                           creates comms/<YYYYMMDD>-<NN>/ from templates,
                           prints the reading manifest (README + that handoff only)
                           (no handoffs at all → bootstraps the folder's first session)
        ... session ...
./comms/session-end.sh    verifies the handoff is section-complete, appends methodology
                           findings to ~/.agent/learnings.md, deletes the SEAL block
```

- **`session-start.sh --resume`** reuses today's newest session folder (same-day continuation).
  Also the crash-recovery hatch: after a wedged agent or lost terminal it reopens today's
  folder with nothing lost (`conversation.md` is append-only). If today has no session folder,
  it falls back to the newest folder from an earlier day — the cross-midnight continuation —
  with a loud note naming which folder it reopened. A resumed sealed folder may be appended
  to, not rewritten; for a fresh session run the script without `--resume` on a later day.
- **`session-end.sh <session>`** is the cross-midnight seal hatch: explicitly seal an earlier
  day's unsealed draft by folder name (e.g. `./comms/session-end.sh 20260908-02`). With no
  argument it seals today's newest session; if today has no session folder it refuses while
  naming the newest unsealed draft and the exact salvage command — it never guesses.
- **Unsealed handoffs are drafts.** The template ships with a `<!-- SEAL: delete this line -->`
  marker; until `session-end.sh` removes it, the file is not canonical, and `session-start.sh`
  will fall back to the newest *sealed* handoff. A session that dies mid-handoff can't poison
  the next session's context.
- **`~/.agent/learnings.md` is the global ledger.** `session-end.sh` copies the session's
  methodology findings there, so cross-project rules survive past the enclosing folder. A
  session that reopened a sealed handoff and grew its findings re-seals with a **delta append**
  (only never-before-recorded lines); an unchanged findings block re-seals as a no-op.
- Both scripts refuse to guess: incomplete handoff sections, or a fresh start forking alongside
  today's still-unsealed session → hard error, not a silent default. No handoffs at all
  bootstraps the first session; unsealed-only history is named explicitly in the intro, never
  silently treated as canonical.

## When things go wrong (escape hatches)

The protocol fails loudly, never destructively: every refusal has a named recovery path,
and none of them loses work.

- **A session dies mid-day** (wedged agent, lost terminal): the session folder is just files
  on disk. Exit the agent, run `./comms/session-start.sh --resume` — same folder, same day.
  A resumed sealed folder may be appended to, not rewritten; for a fresh session run the
  script without `--resume` on a later day.
- **A session dies mid-handoff** (handoff written but never sealed): the SEAL marker makes
  it a draft. The next `session-start.sh` names it as unsealed and falls back to the newest
  *sealed* handoff — a dead session cannot poison the next one. Salvage: finish the draft and
  run `./comms/session-end.sh`. Discard: delete the folder and re-run `session-start.sh`.
- **A session crosses midnight unsealed** (work past 00:00, or you return the next day to a
  draft): nothing strands. `--resume` reopens the newest earlier-day folder — append, don't
  rewrite — and `./comms/session-end.sh <YYYYMMDD>-<NN>` seals it by name. Bare
  `session-end.sh` refuses and names the newest unsealed draft + the exact salvage command.
- **`session-end.sh` refuses (handoff incomplete)**: the completeness fence doing its job.
  Fill the named sections and re-run. Never delete the SEAL marker by hand to force a seal —
  fix the handoff, not the fence.
- **A fresh start is refused ("today's session is still unsealed")**: today already has a
  session folder with a draft handoff. Continue it with `--resume`, seal it, or delete the
  folder to discard it.
- **The scaffold died halfway** (`new-enclosing-folder.sh`): it builds everything in a
  staging dir and moves it into place only when complete, so a half-built target cannot
  exist. If a leftover target folder does exist, delete it and re-run — nothing outside it
  was touched.
- **An agent wedges mid-conversation** (repeats one error forever): the scripts never depend
  on agent cooperation — they only read and write plain files. Exit the agent and resume
  as in the first bullet; re-running the session scripts from a fresh agent always works.

## Folder convention

```
comms/
  README.md                  <- this file: the convention (lasting ordinance)
  session-start.sh           <- the intro (see above)
  session-end.sh             <- the outro (see above)
  templates/                 <- session-handoff.md + conversation.md skeletons
  <YYYYMMDD>-<NN>/           <- one folder per conversation session
    session-handoff.md       <- what a fresh session must know to continue
    conversation.md          <- substance writeup of that conversation
    <anything else>          <- dropped files, notes, supporting material
```

- `<YYYYMMDD>-<NN>` is the date plus a zero-padded sequence number for that day
  (e.g. `20260810-01`, `20260810-02`). The sequence disambiguates multiple sessions on
  the same date. `session-start.sh` derives it automatically.
- A conversation folder is the drop zone for *anything* that adds context to that session —
  files, screenshots, excerpts, scratch notes. The agent and the operator both read from and
  write to it.

## How to resume a new session

1. Run `./comms/session-start.sh` (from the enclosing folder root). It prints the reading
   manifest: this `README.md`, then the newest sealed `session-handoff.md` — the **only**
   comms files a fresh session reads.
2. Read only what the handoff's **"How to resume"** section names. Old days stay closed
   unless that handoff or the operator opens them: a decision made and later abandoned on
   an earlier day must not re-enter context.
3. At session end, write `conversation.md` and the handoff (both from `templates/` if the
   session folder was created without `session-start.sh`), then run
   `./comms/session-end.sh`.

The `session-handoff.md` is the load-bearing artifact for continuity. Each session produces
one in its own folder; the newest sealed one is canonical. Do not edit a past handoff in
place — write a new one in the new session's folder so the history of state stays traceable.

## The handoff contract (what each section is for)

| Section | Purpose | Load-bearing because |
| --- | --- | --- |
| What this session did | The arc + concrete deliverables | Cold reader can summarize the session |
| Canonical state | Snapshot of unit/feature proof status, commit, runtime | Single source of truth |
| **How to resume** | **The reading manifest: exact files, nothing more** | This is the anti-over-read mechanism |
| Methodology findings | Transferable process rules | Copied to `~/.agent/learnings.md` at seal |
| Open problems / decisions needed | Next-session material | Keeps blockers visible across sessions |
| Do not | Fences and standing decisions | Prevents re-litigating settled things |
| Links backward | Explicit pointers to older folders, if load-bearing now | Default "none" — history stays closed |
| Notes for the next session | Style/process/human notes | The operator's channel |

## What goes where

| Artifact | Purpose | Mutability |
| --- | --- | --- |
| `comms/README.md` | The convention itself. | Rarely changes. |
| `comms/templates/*` | Skeletons the scripts stamp out. | Rarely changes. |
| `comms/<date>/session-handoff.md` | Must-know state for the next session. | New file each session. |
| `comms/<date>/conversation.md` | The substance/analysis of one conversation. | Append-only within its session. |
| `comms/<date>/*` | Operator-dropped context files. | Up to the operator. |

## Outside comms/

The enclosing folder root holds the purpose README and the studied/built repos. `comms/`
records the conversation and state; it is not git-tracked.

## The engineering half (what the comms protocol does NOT carry)

This layer carries conversation continuity only. When an idea graduates to a built repo,
the engineering method travels separately — by hand, per the forge-before-abstract rule.
The coffee-shop forge produced these; hand-carry them, don't wait for the scaffold to grow
them:

- **ROADMAP.md pattern** — unit sequence; each unit = problem → outcome → proof obligations
  → context contracts → done; governance rules (map changes at intent time, units touch
  only their listed contexts, proof before delegation, cheap verifiability, lanes as
  parallelization boundaries); regression duty (every unit's proof re-proves the priors).
- **intent/TEMPLATE.md** — one-unit contract: Problem, Proposed outcome + proof artifacts +
  invariants, Affected systems, Bounded contexts + boundary contracts + split rationale,
  Constraints, Open questions (resolved format), NOT-list, Next steps.
- **CONTEXT-MAP.md** — bounded contexts table, contracts table, coupling points documented
  with their revisit triggers.
- **.evidence/ per unit** — numbered JSON artifacts (01-…, 02-…) + PROOF.md (mode, lane
  review, artifacts, gate notes, verdict). Gate re-proves workers' claims; evidence labels
  are written by humans and can be wrong — trace before claiming a bug.
- **verify-<app> skill** — the acceptance gate: real-app control CLI (doctor, product
  commands, browser for UI), structured JSON outcomes, feature docs as the regression
  index. Forge with `create-verification-skill` before delegating any unit.
- **1:N delegation pattern** — seed unit inline first; parallel lanes on disjoint files
  (contract design is collision avoidance); gate re-proves every claim; flash-tier workers
  for mechanical contract-to-code work; shared-stack interference is real — isolated
  compose instances or serialized lane proofs next escalation.

Promote into the scaffold only on the third real enclosing folder, when the friction of
hand-carrying has been felt twice (forge → abstract, per the learnings ledger).
PROTOCOL

cat > "$TARGET/comms/session-start.sh" <<'SCRIPT_EOF'
#!/usr/bin/env bash
# session-start.sh — enclosing-folder session intro.
# Creates (or reuses) today's session folder from templates, resolves the newest
# SEALED session-handoff to resume from, and prints the reading manifest. Run this
# from the enclosing folder root before opening an agent session (or first thing
# inside one). On a fresh folder with no handoffs at all, bootstraps the first
# session instead of failing.
#
# Portable: runs on stock macOS bash 3.2 — no mapfile, no negative array indices,
# no in-place sed. The ${a[@]+"${a[@]}"} idiom iterates a possibly-empty array
# safely under set -u on bash < 4.4 (where "" on an empty array is an error).
#
# Usage: ./comms/session-start.sh [--resume]
#   --resume   reuse today's newest session folder instead of creating a new one.
#              The escape hatch when a session dies mid-day: exit the agent, run
#              this, continue in the same folder — nothing is lost. If today has
#              no session folder, falls back to the newest folder from an earlier
#              day (cross-midnight continuation) — append, don't rewrite.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SEAL='<!-- SEAL:'   # the draft marker line written by the template (fixed string)
COMMS="$ROOT/comms"
TEMPLATES="$COMMS/templates"

die() { echo "session-start: $*" >&2; exit 1; }

[[ -f "$TEMPLATES/session-handoff.md" && -f "$TEMPLATES/conversation.md" ]] \
  || die "missing $TEMPLATES templates — the comms scaffold is damaged"

# --- resolve this session's folder ----------------------------------------------
RESUME="${1:-}"
[[ -z "$RESUME" || "$RESUME" == "--resume" ]] || die "usage: $0 [--resume]"

TODAY="$(date +%Y%m%d)"
todays=()
while IFS= read -r d; do todays+=("$d"); done \
  < <(find "$COMMS" -maxdepth 1 -mindepth 1 -type d -name "$TODAY-*" | sort)
LAST=$(( ${#todays[@]} - 1 ))   # index of today's newest; used only under a count guard

if [[ "$RESUME" == "--resume" ]]; then
  if (( ${#todays[@]} )); then
    SESS_DIR="${todays[$LAST]}"
  else
    # cross-midnight continuation: today has no session folder — fall back to
    # the newest folder from any earlier day (session folders sort by date).
    SESS_DIR="$(find "$COMMS" -maxdepth 1 -mindepth 1 -type d -name '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9]' | sort | tail -n 1)"
    [[ -n "$SESS_DIR" ]] || die "--resume: no session folder at all to reuse (none from today ($TODAY-*), none from earlier days) — start a fresh one without --resume"
    echo "note: no session folder from today ($TODAY-*) — resuming comms/$(basename "$SESS_DIR"), the newest from an earlier day (cross-midnight continuation; append, don't rewrite)" >&2
  fi
  SESS="$(basename "$SESS_DIR")"
  if [[ -f "$SESS_DIR/session-handoff.md" ]] && ! grep -qF "$SEAL" "$SESS_DIR/session-handoff.md"; then
    echo "note: comms/$SESS is already sealed — resuming reopens it; append, don't rewrite. (For a fresh session, run without --resume on a later day.)" >&2
  fi
else
  # a fresh session must not fork alongside today's still-unsealed one
  if (( ${#todays[@]} )); then
    TODAYS_NEWEST="${todays[$LAST]}/session-handoff.md"
    if [[ -f "$TODAYS_NEWEST" ]] && grep -qF "$SEAL" "$TODAYS_NEWEST"; then
      die "today's session ($(basename "${todays[$LAST]}")) is still unsealed — continue it with --resume, seal it with ./comms/session-end.sh, or delete the folder and re-run to discard it. Cross-midnight: --resume and ./comms/session-end.sh $(basename "${todays[$LAST]}") still work next day."
    fi
  fi
  N=1
  while [[ -e "$COMMS/$TODAY-$(printf '%02d' "$N")" ]]; do N=$((N+1)); done
  SESS="$TODAY-$(printf '%02d' "$N")"
  SESS_DIR="$COMMS/$SESS"
  mkdir "$SESS_DIR"
  sed "s/{{DATE-SEQ}}/$SESS/g" "$TEMPLATES/session-handoff.md" > "$SESS_DIR/session-handoff.md"
  sed "s/{{DATE-SEQ}}/$SESS/g" "$TEMPLATES/conversation.md" > "$SESS_DIR/conversation.md"
fi

# --- resolve the sealed handoff to resume from ----------------------------------
# Our own folder's draft never counts. Newest sealed wins; unsealed drafts are
# skipped — a session that died mid-handoff must not poison the next session's
# context. With no sealed handoff at all, say so instead of guessing.
handoffs=()
while IFS= read -r f; do handoffs+=("$f"); done \
  < <(find "$COMMS" -maxdepth 2 -name session-handoff.md | grep -v templates | sort)

PREV_SEALED=""
DRAFT=""
ALL_BUT_OWN=()
for f in ${handoffs[@]+"${handoffs[@]}"}; do
  [[ "$f" == "$SESS_DIR/session-handoff.md" ]] || ALL_BUT_OWN+=("$f")
done
if (( ${#ALL_BUT_OWN[@]} )); then
  NEWEST="${ALL_BUT_OWN[$(( ${#ALL_BUT_OWN[@]} - 1 ))]}"
  if grep -qF "$SEAL" "$NEWEST"; then
    DRAFT="$NEWEST"
    for f in "${ALL_BUT_OWN[@]:0:$(( ${#ALL_BUT_OWN[@]} - 1 ))}"; do
      grep -qF "$SEAL" "$f" || PREV_SEALED="$f"
    done
    if [[ -n "$PREV_SEALED" ]]; then
      echo "warning: newest handoff is an unsealed draft — resuming from the newest sealed handoff instead:" >&2
      echo "  $PREV_SEALED" >&2
    fi
  else
    PREV_SEALED="$NEWEST"
  fi
fi

# --- print the intro ------------------------------------------------------------
NEWEST_ALL=""
if (( ${#handoffs[@]} )); then NEWEST_ALL="${handoffs[$(( ${#handoffs[@]} - 1 ))]}"; fi
if [[ "$RESUME" == "--resume" && "$SESS_DIR/session-handoff.md" == "$NEWEST_ALL" ]] \
   && [[ -f "$SESS_DIR/session-handoff.md" ]] && ! grep -qF "$SEAL" "$SESS_DIR/session-handoff.md"; then
  # resumed the newest session and it is already sealed: its own handoff IS the
  # canonical state (pointing at an older sealed handoff here would step backwards)
  PRIOR="Continuing sealed session comms/$SESS — its own handoff IS the current canonical state; append, don't rewrite."
  SECOND="  2. comms/$SESS/session-handoff.md   — this session's own sealed handoff (canonical state)"
elif [[ -n "$PREV_SEALED" ]]; then
  PREV_DIR="$(basename "$(dirname "$PREV_SEALED")")"
  PRIOR="Resuming from sealed handoff: comms/$PREV_DIR/session-handoff.md"
  SECOND="  2. comms/$PREV_DIR/session-handoff.md   — canonical state + its \"How to resume\" manifest"
elif [[ "$RESUME" == "--resume" && ${#ALL_BUT_OWN[@]} -eq 0 ]]; then
  PRIOR="Continuing session comms/$SESS — no older handoff exists; this session's own draft handoff is the current state."
  SECOND="  2. comms/$SESS/session-handoff.md   — this session's own draft handoff (the only prior state)"
elif [[ -n "$DRAFT" ]]; then
  DRAFT_DIR="$(basename "$(dirname "$DRAFT")")"
  PRIOR="No sealed handoff exists — the newest is an UNSEALED draft (comms/$DRAFT_DIR/), not canonical; treat prior state as unproven. Escape hatches: salvage it by finishing it + ./comms/session-end.sh $DRAFT_DIR, or delete the folder and re-run this script for a clean start."
  SECOND="  2. README.md at the enclosing-folder root — this folder's purpose and conventions (no sealed handoff)"
else
  PRIOR="No prior handoff — this is the first session in this enclosing folder. This session's handoff becomes the first."
  SECOND="  2. README.md at the enclosing-folder root — this folder's purpose and conventions (no prior handoff)"
fi

cat <<EOF

=== Session intro — $SESS ===
$PRIOR
This session's folder: comms/$SESS/   (drop files here; conversation.md is append-only)

READ, in order (the only comms context at session start):
  1. comms/README.md                      — the convention (rarely changes)
$SECOND

That's it. No other comms files, no prior-art, unless the handoff or the operator names them.

When the session ends, run: ./comms/session-end.sh
EOF
SCRIPT_EOF

cat > "$TARGET/comms/session-end.sh" <<'SCRIPT_EOF'
#!/usr/bin/env bash
# session-end.sh — enclosing-folder session outro.
# Verifies this session's conversation.md exists, that the handoff is complete against
# the template's section list, deletes the SEAL block, and appends the methodology
# findings to ~/.agent/learnings.md. Run from the enclosing folder root at
# session end. Refuses to seal an incomplete handoff. Refuses to guess which
# session is "this" one: with no session folder from today it names the exact
# salvage command instead of silently sealing an older draft.
#
# Portable: runs on stock macOS bash 3.2 — no mapfile, no negative array indices,
# no in-place sed (portable in-place edit = temp file + mv over the original).
# Usage: ./comms/session-end.sh [<session>]   e.g. ./comms/session-end.sh 20260908-02
#   No argument  seals today's newest session folder (the normal case).
#   <session>    explicit folder name — the cross-midnight hatch: seals an
#                earlier day's unsealed draft that session-start fell back past.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMMS="$ROOT/comms"
SEAL='<!-- SEAL: delete this line'

die() { echo "session-end: $*" >&2; exit 1; }

# --- locate this session's folder ----------------------------------------------
# Precedence: an explicit <session> argument (the cross-midnight salvage hatch)
# beats today's-newest. With neither, refuse while naming the exact command.
arg="${1:-}"
if [[ "$arg" == --* ]]; then
  case "$arg" in
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//;s/^#//' | sed '/^$/d'; exit 0 ;;
  esac
  die "unknown option '$arg' — session-end takes a session folder name (or nothing for today's newest); --resume belongs to session-start.sh"
fi
# a session name must be a date-sequence folder: anything else (e.g. "templates")
# could point the seal at a non-session file — refuse rather than guess.
case "$arg" in
  "") : ;;
  [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9]) : ;;
  *) die "'$arg' is not a session folder name (want YYYYMMDD-NN, e.g. 20260908-02)" ;;
esac
SESS_DIR="$COMMS/${arg:-}"
if [[ -n "$arg" ]] && [[ ! -d "$SESS_DIR" ]]; then
  die "no comms/$arg folder — usage: $0 [<session folder name>]"
fi

TODAY="$(date +%Y%m%d)"
todays=()
while IFS= read -r d; do todays+=("$d"); done \
  < <(find "$COMMS" -maxdepth 1 -mindepth 1 -type d -name "$TODAY-*" | sort)
if [[ -z "$arg" ]]; then
  if [[ ${#todays[@]} -eq 0 ]]; then
    DRAFT_CAND=""
    while IFS= read -r f; do
      # keep overwriting: sorted ascending, so the last unsealed draft = newest
      grep -qF "$SEAL" "$f" && DRAFT_CAND="$f" || true
    done < <(find "$COMMS" -maxdepth 2 -name session-handoff.md | grep -v templates | sort)
    if [[ -n "$DRAFT_CAND" ]]; then
      DRAFT_SESS="$(basename "$(dirname "$DRAFT_CAND")")"
      die "no session folder from today ($TODAY-*) — the newest unsealed draft is comms/$DRAFT_SESS; salvage it with ./comms/session-end.sh $DRAFT_SESS, or delete the folder to discard it"
    fi
    die "no session folder from today ($TODAY-*) — nothing newer to seal; if an older session was left unsealed, name it explicitly: ./comms/session-end.sh <YYYYMMDD>-<NN>"
  fi
  SESS_DIR="${todays[$(( ${#todays[@]} - 1 ))]}"
fi
SESS="$(basename "$SESS_DIR")"
HANDOFF="$SESS_DIR/session-handoff.md"
CONVO="$SESS_DIR/conversation.md"

# --- checks --------------------------------------------------------------------
[[ -f "$HANDOFF" ]] || die "missing $HANDOFF"
[[ -f "$CONVO" ]] || die "missing $CONVO — write it before sealing (see comms/templates/conversation.md)"

SECTIONS=(
  "## What this session did"
  "## Canonical state"
  "## How to resume"
  "## Methodology findings"
  "## Open problems / decisions needed"
  "## Do not"
  "## Links backward"
  "## Notes for the next session"
)
MISSING=()
for s in "${SECTIONS[@]}"; do
  # section present AND has content: at least one non-blank line before the next
  # heading that is neither a template comment (<!-- anywhere in the line, incl.
  # after a list number) nor boilerplate (placeholder paths, "ONLY these:"). An
  # untouched template fails this — including an untouched "How to resume".
  awk -v sec="$s" '
    index($0, sec) == 1 { in_sec = 1; next }
    in_sec && /^## / { in_sec = 0 }
    in_sec && $0 !~ /<!--/ && $0 !~ /^[[:space:]]*>/ && $0 !~ /^[[:space:]]*$/ && $0 !~ /(path\/to\/file|ONLY these:|Evidence dirs: `path\/`)/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$HANDOFF" || MISSING+=("$s (empty)")
done
((${#MISSING[@]})) && { printf 'session-end: handoff incomplete:\n  %s\n' "${MISSING[*]}" >&2; exit 1; }

# fill the title placeholder if still present (portable in-place edit)
if grep -q '^# Session handoff — {{DATE-SEQ}}' "$HANDOFF"; then
  sed "s/^# Session handoff — {{DATE-SEQ}}/# Session handoff — $SESS/" "$HANDOFF" > "$HANDOFF.tmp"
  mv "$HANDOFF.tmp" "$HANDOFF"
fi

LEARN="$HOME/.agent/learnings.md"
mkdir -p "$(dirname "$LEARN")" && touch "$LEARN"
# Ledger digests are capped at whole findings. A finding = a numbered line
# (^[0-9]+\.) plus its continuation lines; findings are appended only in full.
# When the 25-line cap is reached the remainder is skipped WITH a loud warning
# naming the handoff as the full source — never a silent mid-sentence cut.
cap_findings() {
  awk '
    BEGIN { cap = 25 }
    function flush() {
      if (buf == "") return
      if (total + nbuf > cap) { trunc = 1; exit 3 }
      printf "%s", buf
      total += nbuf
      buf = ""; nbuf = 0
    }
    $0 ~ /^[0-9]+\./ { flush() }
    { buf = buf $0 "\n"; nbuf++ }
    END { if (!trunc) flush() }
  '
}

# Reopened-session delta: this handoff was sealed (and its findings appended)
# before. If the session was reopened and the findings block grew, append ONLY
# the never-before-appended lines as a follow-up entry; an unchanged findings
# block re-seals as a no-op (idempotent re-seal). seen[] accumulates the lines
# of EVERY prior append for this handoff — each such entry starts at a heading
# containing the handoff path, and in_entry closes at the next "## " heading.
if grep -qF "(handoff: $HANDOFF)" "$LEARN"; then
  rc=0
  DELTA="$(awk -v key="(handoff: $HANDOFF)" '
    FNR==NR {
      if (index($0, key) > 0) { in_entry = 1; next }
      if (in_entry && /^## /) { in_entry = 0; next }
      if (in_entry) seen[$0] = 1
      next
    }
    /^## Methodology findings/ { in_findings = 1; next }
    /^## (Open problems|Do not|Links backward|Notes for)/ { in_findings = 0 }
    in_findings {
      if (!skip && $0 ~ /<!--/) { if ($0 !~ /-->/) skip = 1; next }
      if (skip) { if ($0 ~ /-->/) skip = 0; next }
      sub(/^[[:space:]]+/, "")
      if (length($0) && !($0 in seen)) print
    }
  ' "$LEARN" "$HANDOFF" | cap_findings)" || rc=$?
  if [[ -z "$DELTA" && "$rc" -eq 0 ]]; then
    echo "Learnings already recorded for this handoff — skipping (idempotent re-seal)."
  elif [[ -n "$DELTA" ]]; then
    {
      echo
      echo "## $(date +%Y-%m-%d) — comms session $SESS reopened, enclosing folder $ROOT (handoff: $HANDOFF)"
      printf '%s\n' "$DELTA"
    } >> "$LEARN"
    echo "Appended follow-up findings (reopened session) to ~/.agent/learnings.md"
    [[ "$rc" -ne 0 ]] && echo "warning: reopened findings exceeded the 25-line ledger digest — appended whole findings only; full text: $HANDOFF"
  else
    echo "warning: reopened findings exceeded the 25-line ledger digest — nothing appended; full text: $HANDOFF"
  fi
elif grep -A100 '^## Methodology findings' "$HANDOFF" | grep -qE '^[A-Za-z0-9**-].*' ; then
  rc=0
  DIGEST="$(awk '
    /^## Methodology findings/ { in_findings = 1; next }
    /^## (Open problems|Do not|Links backward|Notes for)/ { in_findings = 0 }
    in_findings {
      # strip template comment blocks (multi-line aware — no sed range semantics),
      # leading whitespace, and blank lines
      if (!skip && $0 ~ /<!--/) { if ($0 !~ /-->/) skip = 1; next }
      if (skip) { if ($0 ~ /-->/) skip = 0; next }
      sub(/^[[:space:]]+/, "")
      if (length($0)) print
    }
  ' "$HANDOFF" | cap_findings)" || rc=$?
  if [[ -n "$DIGEST" ]]; then
    {
      echo
      echo "## $(date +%Y-%m-%d) — comms session $SESS, enclosing folder $ROOT (handoff: $HANDOFF)"
      printf '%s\n' "$DIGEST"
    } >> "$LEARN"
    echo "Appended methodology findings to ~/.agent/learnings.md"
    [[ "$rc" -ne 0 ]] && echo "warning: findings exceeded the 25-line ledger digest — appended whole findings only; full text: $HANDOFF"
  else
    echo "warning: findings exceed the 25-line ledger digest — nothing appended; full text: $HANDOFF"
  fi
fi

# --- seal ----------------------------------------------------------------------
# Delete the whole SEAL comment block — the template's marker spans two lines (an
# orphan continuation line used to survive a single-line delete); a condensed
# one-line marker also works. awk state machine: skip the marker line, then
# continuation lines through the closing `-->`. Portable: no sed -i, no sed ranges.
awk -v seal="$SEAL" '
  !skip && index($0, seal) > 0 { skip = (index($0, "-->") == 0); next }
  skip                         { skip = (index($0, "-->") == 0); next }
  { print }
' "$HANDOFF" > "$HANDOFF.tmp"
mv "$HANDOFF.tmp" "$HANDOFF"
echo "Sealed comms/$SESS/session-handoff.md — it is now the canonical state."
echo "Next session: ./comms/session-start.sh   (same-day continuation: --resume)"
SCRIPT_EOF

cat > "$TARGET/comms/templates/session-handoff.md" <<'TEMPLATE_EOF'
# Session handoff — {{DATE-SEQ}}

<!-- SEAL: delete this line when this handoff is final. While present, this file is a
     draft: session-start.sh will not treat it as canonical, and the folder is unsealed. -->

> Written for a cold reader: the next session reads ONLY this file plus the files its
> "How to resume" manifest names. Everything else in comms/ stays closed until this
> handoff or the operator opens it. Say "none" in a section rather than deleting it.

## What this session did

<!-- 2–6 sentences on the arc, then bullets with concrete deliverables (commits, units,
     artifacts). A reader should be able to summarize the session from this alone. -->

## Canonical state

<!-- The snapshot a fresh session must trust: feature/unit table with proof status,
     master commit, runtime state. This section is the single source of truth. -->

## How to resume   <!-- MANDATORY: the reading manifest for the next session -->

1. <!-- command to bring the stack up -->
2. <!-- command to doctor it -->
3. Files to read for the next piece of work — ONLY these:
   - `path/to/file` — why it matters
4. Evidence dirs: `path/` — what they contain

## Methodology findings

<!-- The transferable rules learned this session. This project's product is the process;
     surface the process here, not just in the code. Never quote the literal SEAL marker
     (the first line of this file's comment block) in prose: it would read as
     forever-unsealed and be deleted at seal. -->

## Open problems / decisions needed

<!-- Real, next-session material. Each item states what decision or work unblocks it. -->

## Do not

<!-- Fences: what a fresh session must not do (anti-patterns, standing decisions). -->

## Links backward

<!-- Explicit pointers into older comms folders — ONLY when that history is load-bearing
     NOW. Default: "none". Old days never re-enter context except through this section. -->

## Notes for the next session

<!-- Style/process notes, oddities, anything human. -->

<!-- Reopened sessions: append to every section, never rewrite. session-end.sh re-seals
     idempotently and appends only the never-before-recorded findings to the ledger. -->
TEMPLATE_EOF

cat > "$TARGET/comms/templates/conversation.md" <<'TEMPLATE_EOF'
# Conversation — {{DATE-SEQ}}

> Substance record for this session: the reasoning, not the state (state lives in
> session-handoff.md). Append-only within the session.

## Threads

<!-- One bullet per thread: what was raised, how it developed, where it landed. -->

## Decisions

<!-- Decisions made this session, one line of rationale each. These are what the next
     session inherits as settled. -->

## Dropped / superseded

<!-- Ideas considered and abandoned, and why. This ledger is what keeps abandoned
     directions from zombie-reviving in later sessions. -->

## Raw drops

<!-- Operator-dropped files in this folder that need a sentence of context each. -->
TEMPLATE_EOF

cat > "$STAGE/AGENTS.md" <<'AGENTS_EOF'
# AGENTS.md — <folder-slug> enclosing folder

This enclosing folder has a **scripted session protocol**. Follow it mechanically:

1. **Session start:** run `./comms/session-start.sh` (add `--resume` for a same-day
   continuation — also the crash-recovery hatch after a wedged agent or lost terminal;
   past midnight, `--resume` reopens the newest earlier-day session with nothing lost).
   Read exactly what it prints — `comms/README.md` and the newest **sealed**
   `session-handoff.md` — and then only files that handoff's "How to resume" manifest names.
   Do not glob comms history, do not scan `prior-art/`, unless the handoff or the operator
   points to a specific file.
2. **Session end:** fill `conversation.md` + `session-handoff.md` in today's session folder
   (from `comms/templates/` if missing), then run `./comms/session-end.sh`. It completeness-
   checks the handoff, appends methodology findings to `~/.agent/learnings.md`, and seals.
   Cross-midnight: with no session folder from today, `session-end.sh` refuses and names
   the exact salvage command (`./comms/session-end.sh <YYYYMMDD>-<NN>`); seal an earlier
   day's draft by folder name. A reopened sealed session appends (delta findings only) and
   re-seals idempotently. If it refuses, the handoff is incomplete — fill the named sections
   and re-run; never delete the SEAL marker by hand.
3. **When things go wrong** (crashed agent, failed scaffold, refused script): the recovery
   paths are scripted and non-destructive — see "When things go wrong" in `comms/README.md`.
   Every refusal names its own hatch; none of them loses work.

Conventions in force: `README.md` at the folder root (folder purpose, what's tracked);
`comms/README.md` (the protocol above, folder layout, handoff contract). Past handoffs are
immutable — write new ones. Work lands in the built repos; conversation lands in `comms/`.

Standing access rules: `prior-art/` clones are read-only reference — read named files when
directed, never scan, never write (a work copy of anything lives at the folder root; parallel
agent work uses git worktrees of the built repo). `artifacts/` holds reference material
(PDFs, decks, exports): open only when the operator or a handoff names the exact file, never
scan it, never commit it.
AGENTS_EOF

finish

echo "Created enclosing folder: $TARGET_REAL"
echo "  - $TARGET_REAL/README.md"
echo "  - $TARGET_REAL/AGENTS.md (session protocol, auto-loaded by agent sessions)"
echo "  - $TARGET_REAL/comms/README.md"
echo "  - $TARGET_REAL/comms/session-start.sh + session-end.sh + templates/"
echo "Next: clone prior-art repos into $TARGET_REAL/prior-art/ (then chmod -R a-w each clone), run ./comms/session-start.sh (from the folder root). Drop operator reference material (PDFs, decks) into $TARGET_REAL/artifacts/."