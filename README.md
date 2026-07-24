# Unhog

Unhog is a native macOS menu-bar app that answers one question:

> What is draining this Mac, and can I stop it safely?

It groups related processes into understandable families such as Playwright,
TypeScript servers, Nx, and normal applications. CPU is measured from real
process-time deltas; memory uses physical footprint with resident memory as a
fallback. All data stays on the Mac.

Its Resource Lens shows each major workload as a share of installed RAM. When
something looks wrong, Unhog explains the project and process chain behind
it, stops that verified workload, then measures what changed.

## Current MVP

- Native SwiftUI `MenuBarExtra`; no Electron or web renderer.
- Adaptive, low-overhead sampling through macOS `libproc`: five seconds while
  calm and two seconds while pressure is rising. Expensive physical-footprint
  reads are limited to processes large or active enough to matter.
- A compact 100%-of-installed-RAM map with stable app colours and an honest
  unattributed remainder.
- A read-only Storage section with disk capacity and an on-demand, cancellable
  scan of common folders. Storage scanning never runs automatically.
- CPU, RAM share, estimated battery impact, duration, process count, project
  folder attribution, parent origin, and real app icons.
- Offline bundled marks for Bun, Node.js, Nx, TypeScript, and Playwright.
- Session-scoped process-family grouping for Playwright, TypeScript servers,
  Nx, and apps. Independent jobs never share a kill target.
- Machine-scaled sustained-load detection so short compile spikes and normal
  large apps do not create noisy alerts.
- Local notifications after 20 seconds of high load.
- One-click normal AppKit quit for GUI apps or `SIGTERM` for developer-tool
  families, followed by an explicit force-quit option if needed.
- Restart detection based on workload identity rather than the old PID.
- A measured before-and-after recovery receipt.
- PID plus process-start-time validation immediately before every signal.
- Permanent protection for macOS system processes, other users’ processes,
  PID 0/1, and Unhog itself.
- Borderless interface with app colours used for identity and amber reserved
  for attention.

## Build and run

Requirements:

- macOS 14 or newer
- Xcode 16 or newer

```sh
chmod +x scripts/package-app.sh
./scripts/package-app.sh
open dist/Unhog.app
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
ResourcePressureDetector -> sustained, explainable incidents
MemoryComposition     -> installed-RAM shares and honest remainder
StorageScanner        -> volume capacity and ranked common-folder usage
ResourceExplainer     -> project, process chain, and top worker
RecoveryVerifier      -> recovered, restarted, or still running
TerminationPolicy     -> pure safety decision
SystemProcessTerminator -> revalidate identity, then signal
AppStore              -> UI state and user intents
SwiftUI views         -> presentation only
```

The views never call process or signal APIs. The termination path first creates
a pure safety plan, then validates the PID, start time, and owner again
immediately before sending `SIGTERM` or `SIGKILL`.

## Design contract

- Default state is compact and calm, with one installed-RAM map.
- The active incident gets one dominant explanation and one primary action.
- No outlined cards or buttons.
- Hierarchy comes from spacing, type, tonal surfaces, and restrained color.
- Technical PIDs and child processes are available through disclosure.
- Battery impact is clearly labelled as an estimate derived from CPU activity.
- Force quit is never the first action.
- Automatic force killing is intentionally outside this MVP.
- Storage cleanup and deletion are intentionally outside this MVP; the
  Storage section only measures folders and reveals them in Finder.

## Known limits

- Unhog can only stop processes owned by the current user.
- Family detection is heuristic and currently specializes in the developer
  tools that caused the original incidents.
- The grey RAM-map remainder deliberately combines macOS, untracked processes,
  and free memory; it does not pretend process totals equal system used memory.
- Notification buttons and user-defined automatic rules are planned, but not
  included in the safety-first MVP.
