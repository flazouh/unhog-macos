# 003 — Unify motion and Reduce Motion behavior

- **Status**: TODO
- **Commit**: dc191bd
- **Severity**: MEDIUM
- **Category**: Cohesion and accessibility
- **Estimated scope**: 4 files, about 90 lines

## Problem

Motion values are scattered:

```swift
// Sources/Culprit/InstalledMemoryMapView.swift:60 — current
.animation(
    reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86),
    value: composition
)

// Sources/Culprit/ProcessActivityRow.swift:100 — current
.animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isExpanded)
.animation(.easeOut(duration: 0.12), value: isHovered)

// Sources/Culprit/DesignSystem.swift:61 — current
.scaleEffect(configuration.isPressed ? 0.985 : 1)
.animation(.easeOut(duration: 0.12), value: configuration.isPressed)
```

The RAM map springs on every sample, which is frequent and can animate layout
while the Mac is already under pressure. Reduce Motion removes disclosure
feedback entirely but still leaves button scale movement.

## Target

Add these SwiftUI motion tokens under `CulpritTheme.Motion`:

```swift
static let quick = Animation.timingCurve(
    0.23, 1, 0.32, 1, duration: 0.14
)
static let enter = Animation.timingCurve(
    0.23, 1, 0.32, 1, duration: 0.20
)
static let move = Animation.timingCurve(
    0.77, 0, 0.175, 1, duration: 0.22
)
static let reduced = Animation.easeOut(duration: 0.20)
```

- Remove the composition spring from the installed-RAM map. Routine samples
  update in place without motion.
- Animate only selection opacity with `quick`; under Reduce Motion use
  `reduced`.
- Row disclosure uses opacity + top movement with `enter`; Reduce Motion uses
  opacity-only with `reduced`.
- Hover remains a 140 ms color/opacity transition; it has no movement.
- Button press uses scale `0.985` + opacity with `quick`. Under Reduce Motion,
  keep opacity feedback and force scale to `1`.

## Repo conventions to follow

- Design tokens live in `Sources/Culprit/DesignSystem.swift`.
- Both `InstalledMemoryMapView` and `ProcessActivityRow` already read
  `accessibilityReduceMotion`.
- Unhog is a crisp diagnostic dashboard: no bounce, overshoot, or looping
  decorative motion.

## Steps

1. Add `CulpritTheme.Motion` with the four exact tokens above.
2. Remove `.animation(..., value: composition)` from
   `InstalledMemoryMapView`.
3. Apply an animation only to segment selection opacity.
4. Build the row-detail transition conditionally:
   `.opacity` for Reduce Motion; `.opacity.combined(with: .move(edge: .top))`
   otherwise.
5. Use `reduced` rather than `nil` for reduced-motion disclosure feedback.
6. Read `accessibilityReduceMotion` inside `BorderlessActionStyle`; prevent
   scale movement while retaining pressed opacity.
7. Replace the hand-written evidence animation in `ResourceLensView` with the
   same tokens.

## Boundaries

- Do NOT animate list reordering or metric sampling.
- Do NOT remove all feedback under Reduce Motion.
- Do NOT change colors, spacing, or action semantics.
- Do NOT add a motion dependency.
- If the source differs from commit `dc191bd`, stop and report drift.

## Verification

- **Mechanical**: run `swift test` and `./scripts/package-app.sh`.
- **Feel check**:
  - Leave the popover open through ten samples; the RAM ribbon does not wobble.
  - Rapidly expand/collapse a row; it retargets smoothly.
  - Press every button with Reduce Motion enabled; opacity responds but the
    button does not scale.
  - Inspect at 10% speed and confirm only transform/opacity animate.
- **Done when**: all motion uses shared tokens, frequent sampling is still,
  and Reduce Motion preserves feedback without position or scale movement.
