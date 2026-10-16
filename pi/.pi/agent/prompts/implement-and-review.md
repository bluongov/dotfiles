---
description: Worker implements, reviewer reviews, worker applies feedback
---
Use one pi-subagents scripted workflow for this request: $@

1. Await runs.run("implement", { agent: "worker", task: ... }) to implement the request.
2. Await runs.run("review", { agent: "reviewer", context: "fresh", task: ... }) with the original request, changed paths and implement.output.
3. Await runs.run("fix", { agent: "worker", task: ... }) to apply concrete review findings and validate the result.

Write one ```js workflow block and call subagent({ workflow: true, async: true }) in the same reply. Use real task strings, not the ellipses above. Check each result.ok and stop on a failed stage. Return the final result. Review is explicitly requested by this command, even if automatic Watchdog would remain off.
