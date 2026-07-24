# Agent session monitoring

Research date: 2026-07-24

## What current tools do

- [abtop](https://github.com/graykode/abtop/blob/main/src/collector/codex.rs)
  finds running Codex processes, maps their open `rollout-*.jsonl` files with
  `lsof`, and parses `session_meta`, `turn_context`, `task_started`, and
  `token_count` events. It calculates Codex context usage from the latest
  `last_token_usage.input_tokens` divided by `model_context_window`.
- [CodexMonitor](https://github.com/Dimillian/CodexMonitor/blob/main/src-tauri/src/shared/local_usage_core.rs)
  reads local Codex rollout JSONL and treats cumulative `total_token_usage`
  snapshots carefully so `last_token_usage` deltas are not counted twice.
- [ccstatusline](https://github.com/sirmalloc/ccstatusline/blob/main/src/utils/context-window.ts)
  consumes Claude Code's official status-line JSON. Its current context value
  combines input, output, cache-creation, and cache-read tokens. The live
  payload can include an exact `context_window_size`.
- Claude Code transcripts contain per-response usage but do not persist the
  exact live status-line context-window size. ccstatusline therefore uses
  reported live values when present and otherwise falls back to a model hint
  or 200,000 tokens in its
  [model context helper](https://github.com/sirmalloc/ccstatusline/blob/main/src/utils/model-context.ts).
- [ccusage](https://github.com/ccusage/ccusage) and similar tools read Claude
  Code JSONL under `~/.claude/projects/` for session-level usage reports.

## Unhog decision

The first Agents tab reads only local files:

- Codex: `~/.codex/sessions/**/*.jsonl`
- Claude: `~/.claude/projects/**/*.jsonl`

It considers only recently modified files, reads a small head and tail rather
than loading complete transcripts, and refreshes every 15 seconds only while
the tab is visible.

Codex context percentages are exact when the rollout reports
`model_context_window`. Claude transcript percentages use a visible `~`
estimate because the transcript does not contain the exact live window size.
Unhog does not call provider APIs or upload transcript data.

## Follow-up

For exact process-to-session CPU and RAM attribution, add the `abtop` approach:
map running agent PIDs to open JSONL files with a throttled `lsof` pass. This
should be optional and much less frequent than Unhog's normal process sample.
