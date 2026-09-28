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
CONVENTION=$'  README.md              <- this file: the folder\'s purpose + conventions\n  comms/                 <- agent/operator conversations and session handoffs (see comms/README.md)\n  work/                  <- edit copies of prior-art repos (work/<repo>), created when a ticket needs changes. All edits + commits land here; prior-art/ stays untouched.\n  artifacts/             <- project-scoped reference material (PDFs, decks, dumps, downloads). Named-by-hand access only: never globbed, never auto-read, never in a reading manifest unless a handoff names the exact file.\n  prior-art/             <- repos we are studying and using for examples (their code; their own git). Read only when directed. Clones here are made read-only: reference, never a work target.\n  <built-repo>/          <- a repo we generate from this work (our code; tracked in git). Created later, once we start building.'

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
   \`comms/README.md\` then the newest **sealed** \`comms/<user>/<YYYYMMDD>-<NN>/session-handoff.md\`.
   Those are the only comms files to read at session start. The newest sealed handoff is canonical state.
4. \`prior-art/\` is reference material. Read a file from it **only** when a handoff, conversation, or the operator directs you to that specific file — do not scan or index prior-art by default. Prior-art clones are read-only: if a write there is needed, stop and ask; the work copy lives at the folder root.
5. \`artifacts/\` is reference material the operator dropped or directed. Same access rule: named files only, never a directory scan. It is not comms history and not prior-art — it is source material for the work.
6. Work lands in the built repo(s); conversation/handoffs land in \`comms/\`. Don't commit \`prior-art/\`, \`artifacts/\`, or \`comms/\`.
7. Do not edit past handoffs in place — write a new one in the new session's folder so state stays traceable. \`session-end.sh\` seals.
8. To start a new, unrelated idea, make a new enclosing folder (run \`new-enclosing-folder.sh\`).

## This folder
- Prior-art repos are cloned into \`prior-art/\` as needed and made read-only on arrival; repos we build are created at the root later, once study and conversation justify it. Reference material (PDFs, decks) lands in \`artifacts/\`, not comms.
- Repos from prior-art that a ticket needs changed are cloned to \`work/<repo>\` and edited there — never write into \`prior-art/\`. Honor operator instructions about folder layout as acceptance criteria.
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
./comms/session-start.sh  finds the newest SEALED handoff (canonical state — the
                           caller's own newest first, then across all users),
                           creates comms/<user>/<YYYYMMDD>-<NN>/ from templates,
                           prints the reading manifest (README + that handoff only)
                           (no handoffs at all → bootstraps the folder's first session)
        ... session ...
./comms/session-end.sh    verifies the handoff is section-complete, appends methodology
                           findings to ~/.agent/learnings.md, deletes the SEAL block
```

- **Sessions are keyed by OS user** (`comms/<user>/<YYYYMMDD>-<NN>/`). Attribution is
  structural, sequence numbers are per-user, and mind notes nest per user
  (`comms/<user>/<sess>/mind/`). The CANONICAL STATE is cross-user: the newest sealed
  handoff anywhere in `comms/` is what the next session resumes from, whoever wrote it —
  that is the shared context working.
- **`session-start.sh --resume`** reuses the calling user's newest session folder (same-day
  continuation). Also the crash-recovery hatch: after a wedged agent or lost terminal it
  reopens the user's folder with nothing lost (`conversation.md` is append-only). If the
  user has no session folder from today, it falls back to their newest from an earlier day
  — the cross-midnight continuation; if the user has none at all, it falls back to the
  newest SEALED handoff across all users, with a loud note. Append, don't rewrite; a
  fresh session runs the script without `--resume` on a later day.
- **`session-end.sh [<user>/]<session>`** is the cross-midnight AND cross-user seal hatch:
  explicitly seal an unsealed draft by folder name (e.g. `./comms/session-end.sh
  dw/20260908-02`; a bare date-seq means the calling user's). With no argument it seals
  the calling user's newest session from today; if that user has none it refuses while
  naming the newest unsealed draft (any user's, prefixed) and the exact salvage command —
  it never guesses. Cross-user seals write the ledger digest to the SEALING user's
  `~/.agent/learnings.md`.
- **Unsealed handoffs are drafts.** The template ships with a `<!-- SEAL: delete this line -->`
  marker; until `session-end.sh` removes it, the file is not canonical, and `session-start.sh`
  will fall back to the newest *sealed* handoff. A session that dies mid-handoff can't poison
  the next session's context.
- **`~/.agent/learnings.md` is the global ledger.** `session-end.sh` copies the session's
  methodology findings there, so cross-project rules survive past the enclosing folder. A
  session that reopened a sealed handoff and grew its findings re-seals with a **delta append**
  (only never-before-recorded lines); an unchanged findings block re-seals as a no-op.
- Both scripts refuse to guess: incomplete handoff sections, or a fresh start forking
  alongside the CALLING USER's still-unsealed session → hard error, not a silent default
  (another user's open session never blocks you). No handoffs at all bootstraps the first
  session; unsealed-only history is named explicitly in the intro, never silently treated
  as canonical.

## When things go wrong (escape hatches)

The protocol fails loudly, never destructively: every refusal has a named recovery path,
and none of them loses work.

- **A session dies mid-day** (wedged agent, lost terminal): the session folder is just files
  on disk. Exit the agent, run `./comms/session-start.sh --resume` — same folder, same day
  (it reopens the calling user's newest). A resumed sealed folder may be appended to, not
  rewritten; for a fresh session run the script without `--resume` on a later day.
- **A session dies mid-handoff** (handoff written but never sealed): the SEAL marker makes
  it a draft. The next `session-start.sh` names it as unsealed and falls back to the newest
  *sealed* handoff — a dead session cannot poison the next one. Salvage: finish the draft and
  run `./comms/session-end.sh`. Discard: delete the folder and re-run `session-start.sh`.
- **A session crosses midnight unsealed** (work past 00:00, or you return the next day to a
  draft): nothing strands. `--resume` reopens the user's newest earlier-day folder — append,
  don't rewrite — and `./comms/session-end.sh <user>/<YYYYMMDD>-<NN>` seals it by name (a
  bare date-seq means the calling user's). Bare `session-end.sh` refuses and names the
  newest unsealed draft + the exact prefixed salvage command.
- **A colleague's session was abandoned unsealed**: anyone may seal it —
  `./comms/session-end.sh <user>/<YYYYMMDD>-<NN>`. Cross-user seals append the findings
  digest to the SEALING user's ledger; say what you did, not what they did.
- **`session-end.sh` refuses (handoff incomplete)**: the completeness fence doing its job.
  Fill the named sections and re-run. Never delete the SEAL marker by hand to force a seal —
  fix the handoff, not the fence.
- **A fresh start is refused ("your session is still unsealed")**: the CALLING USER already
  has a session folder today with a draft handoff. Continue it with `--resume`, seal it, or
  delete the folder to discard it. Another user's open session never blocks you.
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
  <user>/                    <- one subfolder per OS user (pd, dw, ...) — attribution
    <YYYYMMDD>-<NN>/         <- one folder per conversation session (sequence per user)
      session-handoff.md     <- what a fresh session must know to continue
      conversation.md        <- substance writeup of that conversation
      mind/                  <- bro-mode mind notes for this session (if used)
      <anything else>        <- dropped files, notes, supporting material
```

- Sessions live at `comms/<user>/<YYYYMMDD>-<NN>`. `<YYYYMMDD>-<NN>` is the date plus a
  zero-padded sequence number for that day, per user (e.g. `comms/pd/20260810-01`,
  `comms/dw/20260810-01`, `comms/pd/20260810-02`). `session-start.sh` derives both the
  user and the sequence automatically.
- The canonical handoff chain is CROSS-USER: the newest sealed `session-handoff.md`
  anywhere under `comms/` is the state the next session resumes from. Never edit a past
  handoff in place — write a new one in your own new session's folder.
- On a shared box, file ownership must not block the protocol: the group needs rwX on
  `comms/` (setgid dirs + `umask 002`), so either user can create/seal sessions. See the
  enclosing folder's README/deployment notes for the group setup.
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
one in its own folder; the newest sealed one is canonical (across all users). Do not edit a
past handoff in place — write a new one in your own new session's folder so the history of
state stays traceable.

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
| `comms/<user>/<date>/session-handoff.md` | Must-know state for the next session. | New file each session. |
| `comms/<user>/<date>/conversation.md` | The substance/analysis of one conversation. | Append-only within its session. |
| `comms/<user>/<date>/*` | Operator-dropped context files. | Up to the operator. |

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
# Creates (or reuses) the calling user's session folder from templates, resolves the
# newest SEALED session-handoff to resume from (the caller's newest first; across all
# users when the caller has none), and prints the reading manifest. Run this from the
# enclosing-folder root before opening an agent session (or first thing inside one).
# On a fresh folder with no handoffs at all, bootstraps the first session instead of
# failing.
#
# Multi-user layout (shared-context box): sessions are keyed by Linux user —
#   comms/<user>/<YYYYMMDD>-<NN>/
# so attribution is structural and sequence numbers stay per-user. On a single-user
# box this is the degenerate case: everything lives under comms/<that-user>/. The
# CANONICAL STATE stays cross-user: the newest sealed handoff anywhere in comms/ is
# what a fresh session resumes from, whoever wrote it.
#
# Portable: runs on stock macOS bash 3.2 — no mapfile, no negative array indices,
# no in-place sed. The ${a[@]+"${a[@]}"} idiom iterates a possibly-empty array
# safely under set -u on bash < 4.4 (where "" on an empty array is an error).
#
# Usage: ./comms/session-start.sh [--resume]
#   --resume   reuse the calling user's newest session folder instead of creating
#              a new one. The escape hatch when a session dies mid-day: exit the
#              agent, run this, continue in the same folder — nothing is lost. If
#              the user has no session folder, falls back to their newest from an
#              earlier day (cross-midnight continuation); if the user has none at
#              all, falls back to the newest SEALED handoff across ALL users —
#              the cross-user shared context — with a loud note. Append, don't rewrite.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SEAL='<!-- SEAL:'   # the draft marker line written by the template (fixed string)
COMMS="$ROOT/comms"
TEMPLATES="$COMMS/templates"
USER_NAME="${USER:-$(id -un)}"   # sessions are keyed by the OS user (pd, dw, ...)

die() { echo "session-start: $*" >&2; exit 1; }

[[ -f "$TEMPLATES/session-handoff.md" && -f "$TEMPLATES/conversation.md" ]] \
  || die "missing $TEMPLATES templates — the comms scaffold is damaged"
case "$USER_NAME" in
  ""|*[!a-zA-Z0-9_.-]*) die "unusable user name '$USER_NAME' — cannot derive comms/$USER_NAME" ;;
esac
USER_COMMS="$COMMS/$USER_NAME"

# --- resolve this session's folder ----------------------------------------------
RESUME="${1:-}"
[[ -z "$RESUME" || "$RESUME" == "--resume" ]] || die "usage: $0 [--resume]"

TODAY="$(date +%Y%m%d)"
# session folders anywhere under comms/ (comms/<user>/<date>-<seq>). Listed as
# "date-seq <tab> path" pairs so ordering is by date-sequence across users, never
# by user name; sed keeps it bash-3.2-safe. `|| true` as above: comms/ itself is
# absent in a fresh scaffold before the first session.
list_sessions() {
  { find "$COMMS" -mindepth 3 -maxdepth 3 -type d -name '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9]' 2>/dev/null || true; } \
    | sed "s|$COMMS/||" \
    | awk -F/ '{ printf "%s\t%s\n", $2, $1 "/" $2 }' \
    | sort
}
# user's own folders, same tab format, ordered by date-seq. The `|| true` keeps the
# pipeline green when the user has no folder yet (find exits 1 on a missing starting
# point even with stderr suppressed; with pipefail that would kill the whole
# substitution — and under set -e a bare find on a missing path kills the script).
list_own_sessions() {
  { find "$USER_COMMS" -mindepth 1 -maxdepth 1 -type d -name '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9]' 2>/dev/null || true; } \
    | sed "s|$COMMS/||" \
    | awk -F/ '{ printf "%s\t%s\n", $2, $1 "/" $2 }' \
    | sort
}

OWN_TODAY="$(list_own_sessions | awk -F'\t' -v today="$TODAY" '$1 ~ "^"today"-" { print $2; exit }')"
OWN_LAST="$(list_own_sessions | tail -n 1 | awk -F'\t' '{print $2}')"

if [[ "$RESUME" == "--resume" ]]; then
  if [[ -n "$OWN_LAST" ]]; then
    SESS_REL="$OWN_LAST"
    if [[ "$OWN_TODAY" != "$OWN_LAST" || -z "$OWN_TODAY" ]]; then
      echo "note: no session folder from today ($TODAY-*) under comms/$USER_NAME/ — resuming comms/$OWN_LAST, the caller's newest from an earlier day (cross-midnight continuation; append, don't rewrite)" >&2
    fi
  else
    # The caller has no sessions anywhere: cross-user continuation. Newest sealed
    # handoff across ALL users is canonical state — resume from it (append, don't
    # rewrite; you are appending to a colleague's record, so say what YOU did).
    SESS_REL="$(list_sessions | tail -n 1 | awk -F'\t' '{print $2}')"
    [[ -n "$SESS_REL" ]] || die "--resume: no session folder at all to reuse (none from $USER_NAME, none from anyone) — start a fresh one without --resume"
    if ! grep -qF "$SEAL" "$COMMS/$SESS_REL/session-handoff.md" 2>/dev/null; then
      die "--resume: no sealed handoff to resume from — the newest session (comms/$SESS_REL) is still an unsealed draft; start a fresh session instead"
    fi
    echo "note: no session folder for $USER_NAME — resuming comms/$SESS_REL, the newest SEALED handoff across users (cross-user shared context; append, don't rewrite — attribute your additions in conversation.md)" >&2
  fi
  SESS_REL="$(printf '%s' "$SESS_REL" | sed 's|^'"$USER_NAME"'/||')"
  if [[ -f "$COMMS/$USER_NAME/$SESS_REL/session-handoff.md" ]] && ! grep -qF "$SEAL" "$COMMS/$USER_NAME/$SESS_REL/session-handoff.md"; then
    echo "note: comms/$USER_NAME/$SESS_REL is already sealed — resuming reopens it; append, don't rewrite. (For a fresh session, run without --resume on a later day.)" >&2
  fi
  SESS_DIR="$COMMS/$USER_NAME/$SESS_REL"
else
  # a fresh session must not fork alongside the CALLER's own still-unsealed session
  # (another user's open session is theirs; it never blocks you)
  if [[ -n "$OWN_TODAY" ]] && grep -qF "$SEAL" "$COMMS/$OWN_TODAY/session-handoff.md" 2>/dev/null; then
    die "your session (comms/$OWN_TODAY) is still unsealed — continue it with --resume, seal it with ./comms/session-end.sh $OWN_TODAY, or delete the folder and re-run to discard it. Cross-midnight: --resume and ./comms/session-end.sh $OWN_TODAY still work next day."
  fi
  # sequence number is per-user
  N=1
  while [[ -e "$USER_COMMS/$TODAY-$(printf '%02d' "$N")" ]]; do N=$((N+1)); done
  SESS_REL="$TODAY-$(printf '%02d' "$N")"
  mkdir -p "$USER_COMMS"
  SESS_DIR="$USER_COMMS/$SESS_REL"
  mkdir "$SESS_DIR"
  sed "s/{{DATE-SEQ}}/$SESS_REL/g" "$TEMPLATES/session-handoff.md" > "$SESS_DIR/session-handoff.md"
  sed "s/{{DATE-SEQ}}/$SESS_REL/g" "$TEMPLATES/conversation.md" > "$SESS_DIR/conversation.md"
fi
SESS="$USER_NAME/$SESS_REL"

# --- resolve the sealed handoff to resume from ----------------------------------
# Our own folder's draft never counts. Newest sealed wins (ordered by date-seq across
# users); unsealed drafts are skipped — a session that died mid-handoff must not
# poison the next session's context. With no sealed handoff at all, say so instead
# of guessing.
handoffs=()
while IFS= read -r f; do handoffs+=("$f"); done \
  < <({ find "$COMMS" -mindepth 3 -maxdepth 3 -name session-handoff.md 2>/dev/null || true; } | grep -v "$COMMS/templates/" | sort)

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
  PREV_REL="$(printf '%s' "$PREV_SEALED" | sed "s|^$COMMS/||; s|/session-handoff.md$||")"
  PRIOR="Resuming from sealed handoff: comms/$PREV_REL/session-handoff.md"
  SECOND="  2. comms/$PREV_REL/session-handoff.md   — canonical state + its \"How to resume\" manifest"
elif [[ "$RESUME" == "--resume" && ${#ALL_BUT_OWN[@]} -eq 0 ]]; then
  PRIOR="Continuing session comms/$SESS — no older handoff exists; this session's own draft handoff is the current state."
  SECOND="  2. comms/$SESS/session-handoff.md   — this session's own draft handoff (the only prior state)"
elif [[ -n "$DRAFT" ]]; then
  DRAFT_REL="$(printf '%s' "$DRAFT" | sed "s|^$COMMS/||; s|/session-handoff.md||")"
  PRIOR="No sealed handoff exists — the newest is an UNSEALED draft (comms/$DRAFT_REL/), not canonical; treat prior state as unproven. Escape hatches: salvage it by finishing it + ./comms/session-end.sh $DRAFT_REL, or delete the folder and re-run this script for a clean start."
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
# findings to the calling user's ~/.agent/learnings.md. Run from the enclosing-folder
# root at session end. Refuses to seal an incomplete handoff. Refuses to guess which
# session is "this" one: with no session folder from today it names the exact salvage
# command instead of silently sealing an older draft.
#
# Multi-user layout (shared-context box): sessions are keyed by Linux user —
#   comms/<user>/<YYYYMMDD>-<NN>/
# Bare (no-argument) sealing resolves the CALLING user's newest-today. The explicit
# argument is a user-prefixed folder name — `<user>/<YYYYMMDD>-<NN>` — which is also
# the cross-user salvage hatch: anyone may seal a colleague's abandoned draft, and the
# refusal text always names the exact prefixed command.
#
# Portable: runs on stock macOS bash 3.2 — no mapfile, no negative array indices,
# no in-place sed (portable in-place edit = temp file + mv over the original).
# Usage: ./comms/session-end.sh [<user>/<YYYYMMDD>-<NN>]   e.g. ./comms/session-end.sh dw/20260908-02
#   No argument  seals the calling user's newest session folder from today (normal case).
#   <user>/<date-seq>  explicit folder name — the cross-midnight / cross-user hatch:
#                seals an unsealed draft that session-start fell back past (yours or
#                a colleague's).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMMS="$ROOT/comms"
SEAL='<!-- SEAL: delete this line'
USER_NAME="${USER:-$(id -un)}"   # sessions are keyed by the OS user (pd, dw, ...)

die() { echo "session-end: $*" >&2; exit 1; }

[[ -n "$USER_NAME" ]] || die "cannot determine the calling user (USER empty, id -un failed)"
case "$USER_NAME" in
  *[!a-zA-Z0-9_.-]*) die "unusable user name '$USER_NAME' — cannot derive comms/$USER_NAME" ;;
esac
USER_COMMS="$COMMS/$USER_NAME"

# --- locate this session's folder ----------------------------------------------
# Precedence: an explicit <user>/<date-seq> argument (the cross-midnight / cross-user
# salvage hatch) beats the caller's newest-today. With neither, refuse while naming
# the exact command.
arg="${1:-}"
if [[ "$arg" == --* ]]; then
  case "$arg" in
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//;s/^#//' | sed '/^$/d'; exit 0 ;;
  esac
  die "unknown option '$arg' — session-end takes a user-prefixed session folder name (or nothing for your own today's-newest); --resume belongs to session-start.sh"
fi
# a session name must be <user>/<date-seq> (or bare <date-seq>, shorthand for the
# calling user): anything else (e.g. "templates") could point the seal at a
# non-session file — refuse rather than guess. Bash-3.2-safe: no ;& fallthrough —
# explicit if/elif on the slash split.
SESS_USER="$USER_NAME"
if [[ -n "$arg" ]]; then
  if [[ "$arg" == */* ]]; then
    SESS_USER="${arg%%/*}"
    arg="${arg#*/}"
    case "$SESS_USER" in
      ""|*[!a-zA-Z0-9_.-]*) die "'$SESS_USER' is not a usable user name (want <user>/<YYYYMMDD>-<NN>, e.g. dw/20260908-02)" ;;
    esac
    case "$arg" in
      */*) die "too many slashes in the original argument (want <user>/<YYYYMMDD>-<NN>, e.g. dw/20260908-02)" ;;
    esac
  fi
  case "$arg" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9]) : ;;
    *) die "'$arg' is not a session folder name (want <user>/<YYYYMMDD>-<NN>, e.g. dw/20260908-02)" ;;
  esac
fi
SESS_DIR=""
if [[ -n "$arg" ]]; then
  SESS_DIR="$COMMS/$SESS_USER/$arg"
  if [[ ! -d "$SESS_DIR" ]]; then
    # Legacy fallback: a bare <date-seq> may name a pre-fork FLAT session folder
    # (comms/<date-seq>, no user level) — the enclosing folder's own sessions made
    # before the user-keyed layout. Try that before refusing, so old drafts stay
    # sealable with their original name.
    if [[ "$SESS_USER" == "$USER_NAME" && -d "$COMMS/$arg" ]]; then
      SESS_DIR="$COMMS/$arg"
    else
      die "no comms/$SESS_USER/$arg folder — usage: $0 [<user>/<YYYYMMDD>-<NN>]"
    fi
  fi
fi

TODAY="$(date +%Y%m%d)"
todays=()
while IFS= read -r d; do todays+=("$d"); done \
  < <({ find "$USER_COMMS" -mindepth 1 -maxdepth 1 -type d -name "$TODAY-*" 2>/dev/null || true; } | sort)
if [[ -z "$arg" ]]; then
  if [[ ${#todays[@]} -eq 0 ]]; then
    # Legacy fallback: folders created BEFORE the user-keyed layout (this enclosing
    # folder's own pre-fork sessions) live flat at comms/<date-seq>. If the caller
    # has none in the new layout but a flat unsealed draft exists, salvage THAT —
    # refusing here would strand it with no working command.
    FLAT_TODAY=""
    if [[ -d "$COMMS/$TODAY-01" && -f "$COMMS/$TODAY-01/session-handoff.md" ]]; then
      FLAT_TODAY="$COMMS/$TODAY-01"
    fi
    DRAFT_CAND=""
    while IFS= read -r f; do
      # keep overwriting: sorted ascending, so the last unsealed draft = newest
      grep -qF "$SEAL" "$f" && DRAFT_CAND="$f" || true
    done < <({ find "$COMMS" -mindepth 3 -maxdepth 3 -name session-handoff.md 2>/dev/null || true; } | grep -v "$COMMS/templates/" | sort)
    if [[ -n "$DRAFT_CAND" ]]; then
      DRAFT_REL="$(printf '%s' "$DRAFT_CAND" | sed "s|^$COMMS/||; s|/session-handoff.md||")"
      case "$DRAFT_REL" in
        */*) die "no session folder from today ($TODAY-*) under comms/$USER_NAME/ — the newest unsealed draft is comms/$DRAFT_REL; salvage it with ./comms/session-end.sh $DRAFT_REL, or delete the folder to discard it" ;;
        *)   # flat pre-fork draft: seal it directly (the caller is its user)
             SESS_DIR="$COMMS/$DRAFT_REL" ;;
      esac
    elif [[ -n "$FLAT_TODAY" ]]; then
      SESS_DIR="$FLAT_TODAY"
    else
      die "no session folder from today ($TODAY-*) under comms/$USER_NAME/ — nothing newer to seal; if an older session was left unsealed, name it explicitly: ./comms/session-end.sh <user>/<YYYYMMDD>-<NN>"
    fi
  fi
  [[ -n "${SESS_DIR:-}" ]] || SESS_DIR="${todays[$(( ${#todays[@]} - 1 ))]}"
fi
SESS_REL="$(printf '%s' "$SESS_DIR" | sed "s|^$COMMS/||")"
SESS="$SESS_REL"
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
# NOTE: the ledger is the sealing user's own $HOME file; cross-user seals key on the
# handoff's absolute path, which is unique per user per folder — the shared-context
# box gives each user their own ledger by construction.
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
   past midnight, `--resume` reopens the calling user's newest earlier-day session; with
   none of your own, it resumes the newest sealed handoff ACROSS users — the shared
   context). Sessions are keyed by OS user: `comms/<user>/<YYYYMMDD>-<NN>/` — the script
   derives the user and sequence automatically.
   Read exactly what it prints — `comms/README.md` and the newest **sealed**
   `session-handoff.md` — and then only files that handoff's "How to resume" manifest names.
   Do not glob comms history, do not scan `prior-art/`, unless the handoff or the operator
   points to a specific file.
2. **Session end:** fill `conversation.md` + `session-handoff.md` in your session folder
   (from `comms/templates/` if missing), then run `./comms/session-end.sh`. It completeness-
   checks the handoff, appends methodology findings to `~/.agent/learnings.md`, and seals.
   Cross-midnight or cross-user: with no session folder from today for you, `session-end.sh`
   refuses and names the exact salvage command (`./comms/session-end.sh <user>/<YYYYMMDD>-<NN>`);
   seal an unsealed draft by prefixed folder name (yours or a colleague's abandoned one —
   the ledger digest goes to the sealing user). A reopened sealed session appends (delta
   findings only) and re-seals idempotently. If it refuses, the handoff is incomplete — fill
   the named sections and re-run; never delete the SEAL marker by hand.
3. **When things go wrong** (crashed agent, failed scaffold, refused script): the recovery
   paths are scripted and non-destructive — see "When things go wrong" in `comms/README.md`.
   Every refusal names its own hatch; none of them loses work.

Conventions in force: `README.md` at the folder root (folder purpose, what's tracked);
`comms/README.md` (the protocol above, folder layout, handoff contract). Past handoffs are
immutable — write new ones. Work lands in the built repos; conversation lands in `comms/`.

Standing access rules: `prior-art/` clones are read-only reference — read named files when
directed, never scan, never write (a work copy of anything lives at the folder root; parallel
agent work uses git worktrees of the built repo). Ticket work that changes a studied repo
clones it to `work/<repo>` at the folder root and edits there. `artifacts/` holds reference material
(PDFs, decks, exports): open only when the operator or a handoff names the exact file, never
scan it, never commit it.

Finish line: when a change is proven (repro gone, tests green), offer the operator the
push/PR step with exact commands ready — never push without their explicit go, but never
end on a proven fix without offering.
AGENTS_EOF

finish

echo "Created enclosing folder: $TARGET_REAL"
echo "  - $TARGET_REAL/README.md"
echo "  - $TARGET_REAL/AGENTS.md (session protocol, auto-loaded by agent sessions)"
echo "  - $TARGET_REAL/comms/README.md"
echo "  - $TARGET_REAL/comms/session-start.sh + session-end.sh + templates/"
echo "Next: clone prior-art repos into $TARGET_REAL/prior-art/ (then chmod -R a-w each clone), run ./comms/session-start.sh (from the folder root). Drop operator reference material (PDFs, decks) into $TARGET_REAL/artifacts/."