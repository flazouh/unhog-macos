# Contributing to Unhog

Thanks for helping make macOS resource problems easier to understand.

## Development

You need macOS 14 or newer and Xcode 16 or newer.

```sh
swift test
./scripts/package-app.sh
open dist/Unhog.app
```

Keep changes small and focused. For behavior changes, add or update a test in
`Tests/CulpritCoreTests`.

## Safety rules

Process termination is the highest-risk part of Unhog. Changes must preserve:

- protection for system processes, other users, PID 0/1, and Unhog itself;
- PID plus process-start-time validation immediately before sending a signal;
- normal termination before force termination;
- branch-scoped stopping that never includes ancestors or sibling branches.

Please explain any safety-related change clearly in the pull request.
