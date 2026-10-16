// Complexity is a bounded heuristic, not a claim that every long task is difficult.
export const LUNA = "github-copilot/gpt-6-luna";
export const SOL = "github-copilot/gpt-6.1-sol";
const CONTROL_TOOLS = new Set([
  "codemode", "subagent", "subagents_enable", "subagent_supervisor",
  "bg_wait", "complex_watchdog", "tool_search",
]);

export class ComplexityPolicy {
  constructor() { this.mode = "auto"; this.resetTask(); }
  resetTask() {
    this.tools = 0;
    this.delegates = 0;
    this.failures = 0;
    this.seenTools = new Set();
    this.seenChildren = new Set();
  }
  recordTool(id, name, args = {}) {
    if (this.seenTools.has(id)) return;
    this.seenTools.add(id);
    if (!CONTROL_TOOLS.has(name)) this.tools++;
    if (name !== "subagent" || args.action) return;
    // Workflow children are counted from confirmed upstream start events.
    // Do not add legacy planned arrays as well: that double-counts children
    // and these shapes are not enabled in the installed upstream configuration.
    if (typeof args.agent === "string" && !args.workflow) this.delegates++;
  }
  recordChild(runId, childId) {
    const key = `${runId}:${childId}`;
    if (this.seenChildren.has(key)) return;
    this.seenChildren.add(key);
    this.delegates++;
  }
  desired() {
    if (this.mode === "off") return null;
    if (this.mode === "sol") return SOL;
    if (this.mode === "luna") return LUNA;
    if (this.delegates >= 8 || (this.tools >= 60 && this.failures >= 3)) return SOL;
    if (this.delegates >= 3 || this.tools >= 25) return LUNA;
    return null;
  }
  status() {
    return `Mode: ${this.mode}; tools: ${this.tools}; subagents: ${this.delegates}; failed tools: ${this.failures}; requested reviewer: ${this.desired() ?? "off"}`;
  }
}
