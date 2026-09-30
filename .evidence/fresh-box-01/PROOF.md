# PROOF — fresh-box-01 (unit 5: fresh-box.sh box-day bootstrap)

Mode: inline (single unit; no lanes). Date: 2026-09-30.
Contract: `.evidence/fresh-box-01/INTENT.md` (sealed pre-code, ROADMAP unit 5).

## What was built

- `fresh-box.sh` (runbook root, 300 lines, bash-3.2 portable, shellcheck-clean):
  - `--check` — the honest bill, ZERO mutation (deps, dirs, runbook clone state,
    PATH-on-PATH, PATH-statement-in-profile (content-grep: expanded-$HOME AND
    literal-$HOME forms), omp, herdr); exit 0 healthy / 1 gaps.
  - provision order: apt deps (gh-only install via official keyring recipe,
    idempotent re-adds; git+curl = base-image contract → refusal names the hatch)
    → `~/Documents/GitHub` → runbook clone (refuse over foreign checkout;
    `pull --ff-only` refresh; dirty tree → refresh refused) → `~/.local/bin` +
    PATH statement (marker-commented idempotent append; content-greps accept both
    the literal-$HOME legacy form and the expanded form; exports for this shell)
    → omp via machine.yml `omp.install_hint` (only when binary missing) → herdr
    official installer (same) → printed follow-ons it never runs (runbook
    install + doctor, gh device-flow, omp login).
- `install.sh`: §3c fresh-box install block (same PATH gate + cmp refuse-fence),
  §2b doctor `for dexec` loop entry (parity + drift), uninstall line, and the
  PATH-note UX fix ("tools not installed … RE-RUN ./install.sh").
- Docs: README (tree + bare-box paragraph), machine.md § Shared-context box
  step 6 box-day bootstrap paragraph, ROADMAP unit 5.

## Proof map (real runs; JSON in this dir)

| Artifact | Proof |
| --- | --- |
| `01-check-no-mutation.json` | scratch-HOME `--check`: honest rc=1 bill, `find -newer` sentinel → 0 files created; clean-env variant |
| `02-idempotent-run.json` | scratch-HOME full+idempotent runs (marker written once across 4 runs; run2 transitions did:→ok:/note:), foreign-checkout refusal, legacy literal-$HOME bashrc recognized, live-box check green |
| `03-docker-e2e.json` | debian e2e (fresh user, real network): gh 2.102.0 lands via keyring + source + install; clone; installer chain green; doctor parity + drift caught; bash:3.2 alpine leg rc=0 full+idem; base-contract + non-apt refusals proven |
| `04-regression.json` | 28/28 gate host + bash:3.2; shellcheck clean; live doctor "nothing missing, nothing drifted" |

## Gate notes / surprises caught by proofs

1. **PATH-marker check was too strict first (false negative on this laptop):**
   the live box's `~/.bashrc` has an UNMARKED `export PATH="$HOME/.local/bin:$PATH"`
   line — the marker-grep was a false negative (exactly Friday's box the unit
   targets). Fixed to content-grep (both literal and expanded forms); marker
   comment retained only as our own append's provenance comment.
2. **The PATH-case arm leaked a note into MISSING** ("PATH statement missing")
   even when the statement was present — bill_path's two arms conflated. Trace
   (`set -x` inside bill) caught it: the notes now belong 1:1 to their arms.
3. **`A && B || C` anti-pattern** in two verify lines (omp/herdr post-install):
   would have printed the wrong verdict on success+warn. Replaced with if/else.
4. **Root-garbage in the platform-reject message** (`"$1"` interpolated into
   prose) — caught by reading, fixed before any proof.
5. Bash-3.2 leg: alpine ships no apt and no gh — the leg proves interpreter
   compatibility (full flow rc=0 with gh present via PATH stand-in); the REAL
   gh install path (keyring + sources + apt-get) is proven on the debian leg.

## Verdict

PASS — all seven intent proof obligations exercised, both interpreters, real
network; refusals name their hatches; `--check` provably read-only; the box-day
friction list from `comms/patdabney/20260930-01/intro.txt` is now one command.