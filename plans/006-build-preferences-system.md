# 006 — Build the preferences system

- **Status**: DONE
- **Commit**: dc191bd
- **Severity**: HIGH
- **Category**: Product control
- **Estimated scope**: 8 files, about 500 lines

## Problem

Settings currently has one `@AppStorage` toggle. It cannot express login,
display, sensitivity, notification detail, privacy, or advanced monitoring.
Adding more unrelated `@AppStorage` keys directly to views would make defaults,
testing, and future migrations fragile.

## Target

Build the settings model and progressive-disclosure UI described in
`docs/menu-bar-and-settings-spec.md`.

The first screen exposes useful choices:

```text
Start at login
Menu bar          Adaptive
Sensitivity       Balanced
Notifications     Needs attention
Motion            Follow macOS

Advanced…
```

Advanced owns raw thresholds, sampling profile, verification window, reset,
and diagnostics.

## Test seam

Use a pure preference compiler:

```swift
PreferencePolicies.make(from: CulpritPreferences) -> (
    monitoring: MonitoringPolicy,
    menuBar: MenuBarPolicy,
    notifications: NotificationPolicy
)
```

Tests first prove recommended defaults, all presets, safe clamping, round-trip
persistence, migration from `notificationsEnabled`, and notification
permission mismatch behavior.

## Steps

1. Write characterization tests for the current notification default.
2. Add typed preference values and the pure policy compiler.
3. Add `PreferencesRepository`; isolate `UserDefaults` behind its protocol.
4. Migrate the existing `notificationsEnabled` value without losing it.
5. Wire monitoring presets to detector thresholds and sustained duration.
6. Wire sampling profiles while enforcing safe product minimums.
7. Wire Menu bar display to Plan 005's presenter.
8. Add a notification authorization model and `Open System Settings` action.
9. Add launch-at-login through Apple's `ServiceManagement` API.
10. Refactor `SettingsView` into General, Monitoring, Notifications,
    Safety & privacy, and Advanced sections.
11. Add muted-workload management.
12. Add Reset to Balanced and a redacted local diagnostics export.

## Boundaries

- Preferences never produce `TerminationPolicy`.
- Force Quit confirmation is always required.
- No automatic stop or automatic Force Quit.
- No setting disables owner, system-process, self, or identity checks.
- No arbitrary PID selection.
- No analytics or process-data upload.
- Do not present estimated battery impact as measured energy.
- If source differs from `dc191bd`, stop and report drift.

## Verification

- `swift test --filter Preferences`
- `swift test`
- Relaunch and verify every preference persists.
- Upgrade from the current build and verify notification preference migration.
- Deny notifications in macOS and confirm Settings shows the real state.
- Test all controls with keyboard and VoiceOver.
- Confirm Quiet, Balanced, and Early produce distinct deterministic policies.
- Confirm invalid stored values fall back to safe defaults.
