# Culprit

Culprit is a native macOS menu-bar app that answers one question:

> What is making this Mac hot, and can I stop it safely?

It groups related processes into understandable families such as Playwright,
TypeScript servers, Nx, and normal applications. CPU is measured from real
process-time deltas; memory uses physical footprint with resident memory as a
fallback. All data stays on the Mac.

## Current MVP

- Native SwiftUI `MenuBarExtra`; no Electron or web renderer.
- Adaptive, low-overhead sampling through macOS `libproc`: five seconds while
  calm and two seconds while pressure is rising. Expensive physical-footprint
  reads are limited to processes large or active enough to matter.
- CPU, memory, duration, process count, parent origin, and real app icons.
- Session-scoped process-family grouping for Playwright, TypeScript servers,
  Nx, and apps. Independent jobs never share a kill target.
- Sustained-load detection so short compile spikes do not create alerts.
- Local notifications after 20 seconds of high load.
- One-click normal AppKit quit for GUI apps or `SIGTERM` for developer-tool
  families, followed by an explicit force-quit option if needed.
- PID plus process-start-time validation immediately before every signal.
- Permanent protection for macOS system processes, other users’ processes,
  PID 0/1, and Culprit itself.
- Borderless, monochrome interface with heat color used only for real pressure.

## Build and run

Requirements:

- macOS 14 or newer
- Xcode 16 or newer

```sh
chmod +x scripts/package-app.sh
./scripts/package-app.sh
open dist/Culprit.app
```

The packaged development app is ad-hoc signed for local use. Public
distribution will need a Developer ID signature and Apple notarization.

## Tests

```sh
swift test
```

The behavior suite covers:

- Playwright and TypeScript family grouping
- separation of unrelated Playwright sessions
- ordinary application-tree grouping
- sustained versus short-lived CPU pressure
- independent CPU and memory pressure timers
- cooldown behavior
- current-user, Apple system-path, and self-termination safety
- a real `libproc` sampling smoke test

## Architecture

```text
SystemProcessSampler  -> immutable ProcessSample values
ProcessGrouper        -> understandable process families
HeatDetector          -> sustained, explainable incidents
TerminationPolicy     -> pure safety decision
SystemProcessTerminator -> revalidate identity, then signal
AppStore              -> UI state and user intents
SwiftUI views         -> presentation only
```

The views never call process or signal APIs. The termination path first creates
a pure safety plan, then validates the PID, start time, and owner again
immediately before sending `SIGTERM` or `SIGKILL`.

## Design contract

- Default state is quiet, not a dashboard.
- The active incident gets one dominant explanation and one primary action.
- No outlined cards or buttons.
- Hierarchy comes from spacing, type, tonal surfaces, and restrained color.
- Technical PIDs and child processes are available through disclosure.
- Force quit is never the first action.
- Automatic force killing is intentionally outside this MVP.

## Known limits

- Culprit can only stop processes owned by the current user.
- Family detection is heuristic and currently specializes in the developer
  tools that caused the original incidents.
- System-wide memory pressure is a sensible next addition.
- Notification buttons and user-defined automatic rules are planned, but not
  included in the safety-first MVP.
