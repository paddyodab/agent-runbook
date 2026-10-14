# PROOF — prior-art-refresh-01 (2026-10-14)

Mode: inline unit, no delegation. Live-first (mirror contract obeyed: live comms is
canonical, scaffold heredoc re-spliced mechanically, cmp-verified).

## Result: PASS (all six fixture arms + gate + mirror + docs)

| # | Obligation | Result |
| --- | --- | --- |
| 1 | refreshed arm (behind → ff) | PASS — fixture /tmp/enc2: local 5178b8f vs origin 611c452 → run → "prior-art/origin-repo: refreshed (611c452 upstream advance)", head advanced |
| 2 | diverged arm | PASS — local 5f0202d (fork commit, merge-base 5178b8f) → "DIVERGED from origin — fetch done, ff-pull refused", local head KEPT, rc=0 |
| 3 | dirty arm | PASS — modified f.txt, fetch ran, pull skipped, "DIRTY — fetch done, pull skipped", head unchanged |
| 4 | no-remote arm | PASS — `remote remove origin` → "no origin remote — left as-is" |
| 5 | empty / non-repo arms | PASS — no prior-art dir: intro unchanged, silent; prior-art/notarepo (plain dir): skipped, rc=0 |
| 6 | lifecycle gate | PASS — 32/32 host (junk build /tmp/junk-hp5); 32/32 docker bash:3.2 (git+grep provisioned per comms-git-01) |
| 7 | mirror byte-parity | PASS — sed 373,681 of scaffold == live session-start.sh (cmp); junk build session-start byte-identical to live; README heredoc (FOLDER-substituted) == live comms/README.md |
| 8 | doc duty | PASS — live comms/README.md "Prior-art refresh (session-start)" under Outside comms; scaffold comms-README heredoc same; enclosing README heredoc bullet added |

## In-unit bug found & fixed
First fixture run: `git pull --ff-only --quiet` (no remote arg) failed with
"There is no tracking information for the current branch" on a repo whose upstream
was unset — printed nothing (quiet), masqueraded as DIVERGED even when purely
behind. Fix: pull pinned to `git pull --ff-only --quiet origin HEAD` — remote is
explicit, HEAD is the fetched tip, tracking config never required. The bug
reproduced the known class "minimal fixtures unmask unset-config fallbacks"
(20260928-01 addendum).

## Fixture notes
- /tmp/enc2: enclosing folder with comms scaffold + prior-art/origin-repo wired to
  a local bare remote /tmp/fixture-remote.git; divergence created by local commit
  after pushing baseline; ff case by cloning upstream and advancing remotely.
- /tmp/junk-hp5: junk-parent scaffold build (new-enclosing-folder.sh), gate source
  of truth. Ephemeral; results recorded here.

## Files touched
- comms/session-start.sh (live, this folder) — 34-line refresh block + intro tail
- scaffold/new-enclosing-folder.sh — session-start heredoc re-spliced (byte-parity),
  comms/README heredoc bullet, enclosing README heredoc bullet
- comms/README.md (live) — Outside-comms bullet
- ROADMAP.md — unit recorded