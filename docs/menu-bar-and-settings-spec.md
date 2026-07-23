# Menu bar and settings product spec

- **Status**: Implemented
- **Source baseline**: `dc191bd`
- **Principle**: quiet by default, explanatory when something is wrong

## Product decision

Culprit's menu bar item is an adaptive signal, not a permanent system monitor.
It uses only an icon while the Mac looks normal. During an incident, it adds
the metric that explains the alert:

```text
Calm        ○
Attention   ! 5.9c
Memory      ! 06%
Stopping    … 5.9c
Recovered   ✓ 3.2 GB
Restarted   ↻ 5.9c
Partial     △ 2
```

- `5.9c` means the focused workload is using about 5.9 CPU cores.
- `06%` means the focused workload is using 6% of installed RAM.
- `3.2 GB` in the recovered state is the measured drop in workload memory.
- `2` in the partial state means two targeted processes remain.
- The metric changes only with the existing sample cadence.
- Use monospaced, fixed-width digits.
- Do not pulse, spin, or animate the menu bar item continuously.
- Shape and text carry meaning; colour is optional support.

This is the default **Adaptive** display. A user may choose **Icon only** or an
always-visible top-workload CPU/RAM metric.

## State model

Priority is deterministic:

```text
Partial > Restarted > Stopping > High > Attention
        > Recovered > Measuring > Calm
```

| State | Symbol | Text | Lifetime |
| --- | --- | --- | --- |
| Measuring | `circle.dotted` | None | First two valid samples |
| Calm | `circle` | None by default | Until state changes |
| Attention | `exclamationmark.circle` | Primary signal | While incident is active |
| High | `exclamationmark.circle.fill` | Primary signal | While high incident is active |
| Stopping | `ellipsis.circle` | Frozen pre-stop signal | Until verification completes |
| Recovered | `checkmark.circle` | Verified recovered signal | 8 seconds, then calm |
| Restarted | `arrow.clockwise.circle` | Primary signal | Until acknowledged |
| Partial | `exclamationmark.triangle` | Remaining count | Until resolved |

The eight-second recovered state is a delayed state transition, not an
animation timer.

## Interaction

- A normal click always opens the popover.
- Calm opens the overview.
- Attention opens the focused workload and its drain signature.
- Stopping opens progress and disables duplicate stop actions.
- Recovered opens the verified before/after receipt.
- Restarted opens the recreated branch with `Stop again`.
- Partial opens the remaining targets and explicit next steps.
- Never perform a destructive action directly from the menu bar item.
- Do not hide destructive shortcuts behind right-click or Option-click.

VoiceOver speaks the full meaning instead of the compact label:

```text
Culprit. No unusual resource drain.
Culprit. Playwright needs attention and is using about 5.9 processor cores.
Culprit. Stopping 6 Playwright processes.
Culprit. Two targeted processes did not stop.
```

## Settings information architecture

The main Settings window has five sections:

```text
General
Monitoring
Notifications
Safety & privacy
Advanced
```

The first screen shows the recommended controls. Technical threshold fields
remain under Advanced.

Use a compact native sidebar and one borderless content column:

```text
┌────────────────────────────────────────────────────────┐
│ General          Menu bar                              │
│ Monitoring       Adaptive                         [⌄]  │
│ Notifications    Quiet until Culprit needs attention  │
│ Safety & privacy                                      │
│ Advanced         Start at login                  [—]  │
│                  Open Culprit shortcut             —  │
└────────────────────────────────────────────────────────┘
```

Do not wrap every group in a card. Use spacing, labels, and faint separators.
Keep explanations directly below the control they clarify.

### General

| Setting | Options | Default |
| --- | --- | --- |
| Start Culprit at login | On / Off | Off |
| Menu bar display | Adaptive / Icon only / Top CPU / Top RAM | Adaptive |
| Motion | Follow macOS / Reduced | Follow macOS |

`Adaptive` means icon-only while calm and icon plus the incident's primary
metric while attention is needed. Top CPU and Top RAM mean the top visible
workload, not the whole Mac.

The system Reduce Motion setting always wins. Culprit never lets `Full`
override an accessibility choice.

### Monitoring

| Setting | Options | Default |
| --- | --- | --- |
| Alert sensitivity | Quiet / Balanced / Early / Custom | Balanced |
| Watch CPU drain | On / Off | On |
| Watch memory drain | On / Off | On |
| Alert scope | Always / On battery only | Always |
| Muted workloads | Managed list | Empty |
| Pause monitoring | 15 min / 1 hour / Until resumed | Not paused |

Preset meanings:

- **Quiet**: only stronger, longer incidents.
- **Balanced**: ignores normal short compile and launch spikes.
- **Early**: warns sooner, useful during active development or on battery.
- **Custom**: reveals the Advanced threshold controls.

Muting suppresses alerts and suggestions. It does not hide resource use from
the overview and does not make termination less safe.

Pausing is primarily a popover action. While paused, the menu bar item clearly
shows `pause.circle`, the popover says when monitoring resumes, and the user can
resume immediately.

### Notifications

| Setting | Options | Default |
| --- | --- | --- |
| Notifications | On / Off | On, after permission |
| Notify when | Needs attention / Important only | Needs attention |
| Notify when a workload restarts | On / Off | On |
| Notify when recovery is verified | On / Off | Off |
| Notification sound | On / Off | Off |
| Show workload or project names | On / Off | Off |

Show the real macOS permission state. If permission is denied, display
`Open System Settings`; do not leave a toggle that looks enabled but cannot
work. Never notify on every sample.

### Safety & privacy

Editable:

| Setting | Options | Default |
| --- | --- | --- |
| Confirm whole-stack stop | On / Off | On |
| Include project names in the popover | On / Off | On |

Read-only guarantees:

> Culprit monitors and stops only processes owned by you. macOS processes,
> other users' processes, and Culprit itself are protected. Process identities
> are checked again before every stop. Resource data stays on this Mac.

Force Quit always requires an explicit confirmation. It is not a setting.

### Advanced

Advanced settings exist for users who choose `Custom`:

| Setting | Meaning |
| --- | --- |
| CPU threshold | Processor cores, with the raw `% CPU` equivalent secondary |
| Memory threshold | Percentage of installed RAM, with GB equivalent secondary |
| Sustained duration | Time above the threshold before attention |
| Sampling profile | Efficient / Adaptive / Responsive |
| Recovery verification window | How long Culprit checks after a stop |
| Reset to Balanced | Restores recommended monitoring values |
| Export diagnostics | Local, redacted report for support |

Sampling choices must stay within product-owned safe minimums. A custom value
cannot create a hot polling loop.

## Settings that must not exist

The following guarantees are not customizable:

- system-process and other-user protection
- protection of Culprit itself
- PID plus process-start-time identity verification
- graceful stop before Force Quit
- confirmation before Force Quit
- automatic killing or automatic Force Quit
- disabling adaptive sampling limits
- uploading process or project data
- arbitrary PID checkboxes

Whole-stack and branch actions use the same termination safety rules.

## Preference model

Do not spread new `@AppStorage` strings through views. Introduce one value:

```swift
struct CulpritPreferences: Codable, Equatable, Sendable {
    var general: GeneralPreferences
    var monitoring: MonitoringPreferences
    var notifications: NotificationPreferences
    var safety: SafetyPreferences
}
```

One public, deterministic seam derives product behavior:

```text
CulpritPreferences
        |
        +---> MonitoringPolicy
        +---> MenuBarPresentation
        +---> NotificationPolicy
```

The same seam handles defaults and future preference migrations. Termination
protections do not come from preferences.

## Acceptance criteria

- Calm mode is visually quiet and contains no changing number by default.
- An incident explains its primary signal from the menu bar without opening
  the popover.
- Menu bar state changes do not use a display timer or continuous animation.
- Every compact value has a clear spoken accessibility label.
- Recommended settings fit without opening Advanced.
- Custom thresholds use cores and installed-RAM share, not confusing raw
  process percentages.
- macOS notification permission and Culprit's preference cannot disagree
  silently.
- No preference can weaken process identity or termination protection.
- Recovered state shows only a measured, verified improvement.
