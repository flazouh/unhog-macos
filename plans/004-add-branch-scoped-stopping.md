# 004 — Add branch-scoped stopping

- **Status**: TODO
- **Commit**: dc191bd
- **Severity**: HIGH
- **Category**: Safety and user control
- **Estimated scope**: 7 files, about 420 lines

## Problem

The only termination scope is the whole `ProcessGroup`:

```swift
// Sources/CulpritCore/TerminationPolicy.swift:21 — current
public func plan(for group: ProcessGroup) -> TerminationPlan {
    // ...
    targets: group.processes
        .map(\.identity)
        .sorted { $0.pid < $1.pid }
}
```

For a Playwright stack, the user may want to stop Chromium and its helpers
while leaving the runner alive. Arbitrary PID checkboxes would be unsafe and
hard to understand.

## Target

Introduce the domain model recorded in `CONTEXT.md`:

```swift
public struct ProcessBranchID: Hashable, Sendable {
    public let workloadID: ProcessGroupID
    public let root: ProcessIdentity
}

public struct ProcessBranch: Identifiable, Hashable, Sendable {
    public let id: ProcessBranchID
    public let root: ProcessSample
    public let processes: [ProcessSample]
}
```

A Branch contains exactly its root and every observed descendant inside the
same Workload. It never includes ancestors or siblings.

The default view keeps one primary whole-stack action:

```text
[ Quit Playwright ]
```

`See why` expands the causal chain and stoppable top-level branches:

```text
codex → Playwright → Chromium

Stack parts
Chromium       6 processes · 1.1 GB   [Stop branch]
Trace viewer   2 processes · 220 MB   [Stop branch]
```

After a branch stop, show a branch-scoped Recovery Receipt. If the parent
recreates it, say `Chromium is running again`; never silently repeat the stop.

## Repo conventions to follow

- `ProcessIdentity` is PID plus start time and is the only valid signal target.
- `SystemProcessTerminator` revalidates identity, owner, and protection before
  every signal.
- Normal stop is always tried before force.
- Preview fixtures use `actionsEnabled: false` and must never signal.
- Whole-stack stopping remains unchanged and visually primary.

## Steps

1. Add `ProcessBranch` and `ProcessBranchResolver` to CulpritCore.
2. Before implementation, add public-seam tests:
   - selecting Chromium includes Chromium and all descendants;
   - ancestors and sibling branches are excluded;
   - malformed cycles terminate safely without duplicate members;
   - a branch rooted outside the workload cannot be resolved.
3. Define visible branches as immediate children of the workload root plus
   members whose parent is absent from the workload. Hide one-process helper
   branches below 30 MB unless they are the top CPU or memory worker.
4. Add `TerminationPolicy.plan(for branch:)`. Reuse every existing protection
   check. Preserve target order from deepest descendant to branch root so
   helpers are asked to stop before their launcher.
5. Add policy tests proving:
   - only branch identities become targets;
   - protected, other-user, self, and reused identities remain protected;
   - whole-stack plans behave exactly as before.
6. Replace group-only stop state with a scoped value:
   `StopScope.workload(ProcessGroupID)` or
   `StopScope.branch(ProcessBranchID)`.
7. Add `requestStopBranch(_:)` and branch-scoped graceful/force handling to
   `AppStore`. Capture the original branch snapshot and pre-existing matching
   branch identities before signalling.
8. Add branch verification. A branch is recovered only when every original
   identity is gone. A matching new branch is `running again`; surviving
   originals are `partial`.
9. Add the `Stack parts` rows inside the expanded evidence view. Show exact
   branch process count and attributed memory before the action.
10. Add attention, stopping, recovered, running-again, and partial preview
    fixtures for a branch stop.
11. Include branch outcomes in plan 002’s phase transitions.

## Boundaries

- Do NOT offer arbitrary PID checkboxes.
- Do NOT include ancestors or siblings in a branch plan.
- Do NOT automatically stop a recreated branch.
- Do NOT call a branch stop a whole-stack recovery.
- Do NOT send signals without immediate PID/start-time revalidation.
- Do NOT make branch actions visually compete with the primary whole-stack
  action.
- If the source differs from commit `dc191bd`, stop and report drift.

## Verification

- **Mechanical**:
  run focused branch resolver, policy, and recovery tests; then `swift test`.
- **Safety check**:
  use preview fixtures for all UI actions. Never stop a live development stack
  merely to test the interface.
- **Feel check**:
  - A user can explain which processes will stop before clicking.
  - Stopping Chromium leaves the Playwright runner and sibling branches.
  - A recreated Chromium branch says `running again`.
  - Force quit appears only for identities that survived graceful stop.
  - VoiceOver announces branch name, process count, memory, and action scope.
- **Done when**: branch scope is deterministic, independently verified, and
  whole-stack behavior remains backward-compatible.
