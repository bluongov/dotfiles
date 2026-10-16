---
description: Full implementation workflow - scout gathers context, planner creates plan, worker implements
---
Use one pi-subagents scripted workflow for this request: $@

1. Await runs.run("scout", { agent: "scout", task: ... }) to locate relevant code.
2. Await runs.run("plan", { agent: "planner", task: ... }) with the request and scout.output.
3. Await runs.run("implement", { agent: "worker", task: ... }) with the approved constraints and plan.output.

Write one ```js workflow block and call subagent({ workflow: true, async: true }) in the same reply. Use real task strings, not the ellipses above. Check each result.ok; stop and report a failed stage rather than passing its output onward. Return the implementation result. Selective Watchdog handles complex-task review.
