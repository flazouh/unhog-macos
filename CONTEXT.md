# Unhog Resource Monitor

Unhog explains resource-heavy local workloads and lets the user stop a
verified scope without pretending process relationships are more certain than
the observed process tree. It also reports aggregate AI-provider usage:
subscription windows, reset times, credits, and local token volume. It never
shows prompt or transcript content and never launches provider commands.

## Language

**Workload**:
A related process family presented as one resource consumer and one default
stop scope.
_Avoid_: App, problem process, process pile

**Branch**:
One process inside a workload together with all of its observed descendants.
_Avoid_: Part, selection, arbitrary processes

**Whole-stack stop**:
A stop request whose scope is every verified process in a workload.
_Avoid_: Kill all, quit process

**Branch stop**:
A stop request whose scope is one verified branch while sibling branches and
ancestors remain untouched.
_Avoid_: Partial stop, selective kill

**Recovery receipt**:
A verified before-and-after account of what remained, disappeared, or appeared
again after a stop request.
_Avoid_: Success toast, freed-memory claim

**Provider usage**:
Read-only subscription limits and aggregate token volume reported for an AI
provider.
_Avoid_: Session activity, command center, transcript console
