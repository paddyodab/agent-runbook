# PROOF — preamble-01 (the operator's opening ask as a stamped template)

## Mode

Inline unit (single-owner change across two bounded contexts); junk-lifecycle + junk-parent
parity builds; no delegation (blast radius = one template + one stamp line + one intro
notice + one scaffold mirror).

## What was changed

- live `comms/templates/preamble.txt` (new), `comms/session-start.sh` (guard + stamp +
  conditional READ FIRST notice), `comms/session-end.sh` (title-fill sed bugfix),
  `comms/README.md` (rule + tree + row), enclosing `AGENTS.md` (convention clause).
- scaffold mirror `work/agent-runbook/scaffold/new-enclosing-folder.sh`: README, both
  scripts, preamble-template heredocs spliced MECHANICALLY from live (python extraction,
  not transcription), AGENTS.md conventions paragraph spliced from live.
- regression proof of the bugfix: title-fix is covered by lifecycle suite step 5/6/8
  (sealed handoffs whose titles were template-titled in fixtures).

## Artifacts

- `comms/prove-preamble.sh` — 8 assertions, committed (session folder, comms repo @ 060ee51):
  stamp byte-parity, silence-when-empty, READ-FIRST-when-filled (addenda preserved),
  seal-with-preamble, unfilled-preamble-seals, README rows, template intact.
- Host: `preamble proof: 8 passed, 0 failed` (2026-10-14, run twice final tree).
- bash 3.2 (docker `bash:3.2`, entrypoint /usr/local/bin/bash): `8 passed, 0 failed`.
- Lifecycle suite: host 32/32; docker bash 3.2 (`apk add git grep` provisioned, per
  comms-git-01 precedent) 32/32. No regressions from the title-fill fix.
- Scaffold parity build: junk-parent build of `new-enclosing-folder.sh` → cmp ALL protocol
  files byte-identical (session-start.sh, session-end.sh, README.md, 3 templates,
  .gitignore, hooks/pre-push); AGENTS.md identical modulo the `<folder-slug>` header;
  exec bits OK; scaffolded fresh session + filled preamble produced the READ FIRST notice
  end-to-end in the SCAFFOLDED folder.
- Heredoc-extraction parity gate: all four spliced heredoc bodies byte-equal to live.

## Gate notes

- **Real bug found by the junk lifecycle** (session-end.sh, pre-fix): `sed "s/^# Session
  handoff — {{DATE-SEQ}}/# … — $SESS/"` — `$SESS` contains `/`; GNU sed died at char 74
  "unknown option to 's'". Reproduced standalone (`invalid substitute flag: '-'` shape
  for slash-in-replacement) AND under `bash -x` against a junk-padded handoff. Never hit
  in the field because session-start substitutes the placeholder at stamp time; any
  folder-sans-session-start (README-documented path) refused every seal. Fixed with `|`
  delimiters; suite green both interpreters after.
- Three proof-script failures during development were the script's own (filler used
  whole-heading match, missing `How to resume`'s trailing-comment variant; boilerplate
  body text the seal fence rightly excludes; a python3 dep the bash-3.2 image lacks —
  removed). Each re-derived from tool state per learning #4; none was a tool bug.
- docker `bash:3.2` quirk: `/bin/bash` does not exist (entrypoint `bash:…` is
  `/usr/local/bin/bash`); suites invoke via `bash <script>` explicitly.
- awk filled-detection skips header lines (`^#`), blanks, and comment blocks — a template
  comment can never fire the notice (proved by the empty-template assertion).

## Verdict

PASS. Preamble is a stamped, gated-out-of-sealing, READ-FIRST-when-filled protocol file;
mirror is byte-identical; the title-fill bug it walked into is fixed and
regression-covered. Comms tier committed 060ee51 (local; push offered at finish line).