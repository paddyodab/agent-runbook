# Intent — fix bug: session-start fresh start ignores the calling user's own SEALED handoffs

## Problem (the repro)

`session-start.sh` **fresh start** (no `--resume`) with sealed history in the calling
user's own user folder reports "No prior handoff — this is the first session in this
enclosing folder" and points at the root README instead of resuming from canonical
state.

Repro (2026-10-01, real box): `comms/patdabney/` holds three properly sealed handoffs
(`20260929-01`, `20260929-02`, `20260930-01` — none has a SEAL marker; verified with
grep across all four handoff files). `./comms/session-start.sh` still printed "No prior
handoff". Synthetic junk-HOME repro identical byte-for-byte: one sealed handoff at
`comms/patdabney/20260929-01/session-handoff.md`, run as `USER=patdabney` → intro says
"No prior handoff", new `20261001-01` created. Fixture: `/tmp/sbx-start/junk`.

## Root cause

The classification loop, `session-start.sh` lines 134-140:

```bash
for line in ${handoffs[@]+"${handoffs[@]}"}; do
  rel="$(REL_FROM_ENTRY "$line")"
  [[ "$rel" == "$SESS_DIR/session-handoff.md" || ... ]] && continue
  [[ "$rel" == "$USER_NAME/"* ]] && continue   # ← BUG
  ALL_BUT_OWN+=("$rel")
done
```

Two defects:
1. `[[ "$rel" == "$USER_NAME/"* ]]` skips EVERY own-user handoff — sealed ones included
   — contradicting the loop's own comment ("our own folder's *drafts* never count") and
   the script header ("the caller's newest first"). On any single-user box this makes
   `PREV_SEALED` forever empty; every fresh start is a false "first session".
2. Dead code above it: the session-exclusion line compares `$rel` (a `<user>/<date-seq>`
   RELATIVE path) against absolute paths ending in `/session-handoff.md` — never true.
   Its intent — exclude the just-created session's own handoff — is currently performed
   entirely by the buggy `$USER_NAME/*` skip.

## Fix (smallest, root-cause)

Replace the over-broad skip with the exclusion actually intended:
- skip the calling session's own handoff by REL path: `"$rel" == "$SESS"` where `SESS`
  is `<user>/<date-seq>` (the fresh-created current session);
- do NOT skip the rest of the caller's own user folder; own sealed handoffs count as
  canonical-state candidates.

## Proof obligations

1. Fresh start with OWN sealed history resumes from own newest sealed (intro names it).
2. Fresh start when own newest is an UNSEALED draft resumes from the newest sealed
   anywhere (own sealed older OR another user's newer) — with the draft warning.
3. Fresh start when the ONLY history is the fresh session itself → "first session"
   intro (this session's folder excluded by the rel-path check itself).
4. Cross-user resume (u2 from u1) unchanged — lifecycle scenario 7 stays green.
5. Own-unsealed guard (scenario 3) unchanged; `--resume` semantics unchanged.
6. Regression net: full lifecycle suite host + bash:3.2 green (28+2 new baseline).

## NOT-list (fences)

- No changes to `session-end.sh`, templates, seal semantics, or ledger append.
- No changes to `--resume` fallback order (cross-midnight / cross-user hatches).
- No re-sorting of date-seq ordering or its tie-breaker.
- No extension of fresh-box.sh / install.sh scope; comms scripts only.
- No scaffold structure changes beyond the two embedded copies of `session-start.sh`
  (scaffold/new-enclosing-folder.sh heredoc + live comms/ tree via migrate).

## Open questions

- None blocking. Mirror contract noted: the canonical copy is the scaffold heredoc in
  `scaffold/new-enclosing-folder.sh`; the enclosing folder's `comms/session-start.sh`
  is an installation of it (byte-parity checked by the fresh-box cmp fence).