## What changed

<!-- Explain the user-visible behavior and why this change is needed. -->

## Verification

<!-- List the exact tests or manual checks you ran. -->

- [ ] `swift test`
- [ ] I tested any changed process-stopping behavior manually.

## Safety checklist

- [ ] This change does not weaken protection for system processes, other
      users, PID 0/1, or Unhog itself.
- [ ] Process signals still validate PID, start time, and owner immediately
      before termination.
- [ ] Force quit is never the first action.
- [ ] Branch stopping cannot include ancestors or sibling branches.

<!-- Mark safety items that do not apply and briefly explain why. -->

