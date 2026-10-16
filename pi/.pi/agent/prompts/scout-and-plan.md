---
description: Scout gathers context, planner creates implementation plan (no implementation)
---
Use one pi-subagents scripted workflow for this request: $@

1. Await runs.run("scout", { agent: "scout", task: ... }) to find relevant code.
2. Await runs.run("plan", { agent: "planner", task: ... }) with the request and scout.output.

Write one ```js workflow block and call subagent({ workflow: true, async: true }) in the same reply. Use real task strings, not the ellipses above. Check each result.ok and stop on a failed stage. Do NOT implement; return only the plan.
