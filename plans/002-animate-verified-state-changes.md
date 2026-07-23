# 002 — Animate verified state changes

- **Status**: TODO
- **Commit**: dc191bd
- **Severity**: HIGH
- **Category**: Missed opportunities
- **Estimated scope**: 3 files, about 170 lines

## Problem

Attention, stopping, and recovery replace each other without a useful visual
relationship. A transition is declared, but no phase animation drives it:

```swift
// Sources/Culprit/ResourceLensView.swift:18 — current
content
    .transition(.opacity)
```

The important product story—“this workload drained resources, Culprit stopped
it, then verified the change”—currently teleports.

## Target

Use motion to explain state, never to imply success before verification:

```text
attention → stopping → verified sample → receipt
 bars live    freeze      bars drain       check appears
```

- **Attention**: the signature entrance from plan 001 runs once.
- **Stopping**: freeze all metric fills at their last values and animate their
  opacity to 0.55 over 160 ms with
  `timingCurve(0.23, 1, 0.32, 1, duration: 0.16)`.
- **Verified recovery**: after `RecoveryVerifier` returns `.recovered`, show
  the before values and animate RAM and CPU fills to the verified after values
  over 220 ms with
  `timingCurve(0.77, 0, 0.175, 1, duration: 0.22)`.
  Fade the checkmark and `Back to normal` in during the final 140 ms using
  `timingCurve(0.23, 1, 0.32, 1, duration: 0.14)`.
- **Partial**: retain the remaining fill and reveal the force-quit controls
  with a 160 ms ease-out fade. Never drain the bar to zero.
- **Running again**: redraw the verified successor values in amber over
  200 ms. Keep the honest `running again` wording.
- **Branch stop**: animate only the selected branch signature and receipt.
  Sibling branches remain visually stable.
- **Reduce Motion**: every phase uses a 200 ms opacity-only crossfade.

All moving fills must use `scaleEffect` anchored at `.leading` or `.bottom`.
Do not animate width, height, padding, or layout position.

## Repo conventions to follow

- Recovery truth comes from `Sources/CulpritCore/RecoveryVerifier.swift`.
- `ResourceLensView.recovery(_:)` is the only recovery presentation entry.
- `accessibilityReduceMotion` is already read by `ResourceLensView`.
- The receipt already has exact before/after values; preserve them.

## Steps

1. Complete plans 001, 003, and 004 first.
2. Add an internal display phase enum in `ResourceLensView`:
   `measuring`, `calm`, `attention`, `stopping`, `recovered`, `partial`,
   `runningAgain`.
3. Give each phase a stable identity so sample updates do not retrigger phase
   transitions.
4. Add a compact visual comparison to `receiptView`: CPU and RAM rails start
   at `receipt.before` and animate to `receipt.after` only after the verified
   assessment exists.
5. Keep the exact before→after text below or beside each rail.
6. Branch every movement on `accessibilityReduceMotion`; retain opacity.
7. Add preview fixtures for stopping, recovered, partial, and running again.
8. Add the same fixtures for a selected branch while sibling branches remain.

## Boundaries

- Do NOT change verification timing or termination behavior.
- Do NOT display recovery before `RecoveryVerifier` returns.
- Do NOT animate sibling branches during a branch stop.
- Do NOT pulse continuously.
- Do NOT animate routine CPU/RAM sample updates.
- Do NOT add bounce to this diagnostic product.
- If the source differs from commit `dc191bd`, stop and report drift.

## Verification

- **Mechanical**: run `swift test`, package with
  `./scripts/package-app.sh`, and verify the signature.
- **Feel check**:
  - At 10% speed, recovery bars begin at the actual before values and end at
    the actual after values.
  - Partial failure never visually reaches zero.
  - Rapidly changing samples do not restart animations.
  - Reduce Motion keeps only 200 ms crossfades.
- **Done when**: attention, stopping, recovered, partial, and running-again
  states are visually connected without ever getting ahead of verified data.
