# Selective complex-task Watchdog

Installed globally for this Pi user. Run `/reload` in an existing session.

## Behavior

- Simple tasks: Watchdog remains off.
- 3 dispatched/started subagents OR 25 substantive parent tool calls: GPT-6 Luna, high thinking.
- 8 subagents OR 60 substantive parent tool calls with at least 3 failed tool results: GPT-6.1 Sol, high thinking.
- Pi can request Luna early for clearly difficult work, or Sol when Luna is insufficient, using `complex_watchdog`.
- Complexity is a heuristic; tool length and delegate counts are not proof of difficulty.
- Once activated, upstream reviews changed code and delivered orchestration evidence at agent boundaries, with optional checks every 20 tool results.
- Orchestration activity review is enabled, so multi-agent analysis can be reviewed without a code diff. Pure read-only analysis without orchestration has upstream's boundary limits; cadence can still review it during a sufficiently long run.
- No idle reviewer calls and no watchdog attached to every child. Watchdog itself is read-only.
- Automatic counters reset on a new real user prompt, not on extension-generated background completion wakes. Manual modes last for the session.
- Unavailable models/auth errors are reported, not silently switched to another provider.

## Commands

```text
/complex-watchdog status
/complex-watchdog sol
/complex-watchdog luna
/complex-watchdog off
/complex-watchdog auto
/subagents-watchdog status
```

Use `/complex-watchdog` for controls managed by this adapter. Direct upstream settings/commands can conflict with its session overrides. `sol`/`luna` force review on; `off` forces it off; `auto` restores the thresholds.

## Files

- `index.ts`: loads the pinned pi-subagents package exactly once; session-local activation and upstream boundary ordering.
- `policy.mjs`: complexity thresholds, duplicate protection and manual modes.
- `policy.test.mjs`: unit tests and real upstream runtime tests with an injected model-call seam.
- `smoke.mjs`: authenticated model checks and optional real Luna review against disposable files under `/tmp`.
- `~/.pi/agent/settings.json`: pinned package, disabled old example extension, Luna subagent defaults, and Watchdog defaults.
- `~/.pi/agent/WATCHDOG.md`: evidence-focused review instructions.

The original example extension at `~/.pi/agent/extensions/subagent/` remains on disk, excluded by settings. Package auto-loading of its entry point is disabled because this wrapper loads it. Existing workflow prompts have been migrated to the installed scripted-workflow API.

Pi 1.1 Copilot compatibility: upstream Watchdog forwards a resolved IDE token as a raw API-key override, losing OAuth endpoint resolution. The context adapter omits that override only for Copilot nested `streamSimple` calls, allowing the host SDK to resolve its own stored authentication. No credentials are modified or exposed.

## Validation

```bash
node --test ~/.pi/agent/extensions/complex-watchdog/policy.test.mjs
node ~/.pi/agent/extensions/complex-watchdog/smoke.mjs
PI_WATCHDOG_LIVE_SMOKE=1 node ~/.pi/agent/extensions/complex-watchdog/smoke.mjs
```

The optional live smoke spends one small Luna review and asserts it detects subtraction in an intended addition function without editing it. It also asserts persistent settings remain unchanged. Test helpers reference the current Node/Pi installation path; update that path if the host moves.

Backups of original settings and workflow prompts: `~/.pi/agent/backups/complex-watchdog-20261008/`.

The package is pinned to `pi-subagents@0.76.1`. Revalidate the adapter, command seam and authentication behavior before upgrading it. No SWARMER project files were changed.
