import type { ExtensionAPI, ExtensionContext, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { Type } from "@earendil-works/pi-ai";
import registerSubagents from "../../npm/node_modules/pi-subagents/index.js";
import { ComplexityPolicy, LUNA, SOL } from "./policy.mjs";

// Upstream forwards a resolved Copilot IDE token back as a raw apiKey override.
// On Pi 1.1 this bypasses OAuth endpoint selection. Let the host resolve Copilot
// auth at request time instead, just as the working main-session path does.
// No credentials are changed or exposed; other providers retain their options.
export function requestTimeAuthContext(ctx: ExtensionContext): ExtensionContext {
  return new Proxy(ctx, {
    get(target, key) {
      if (key !== "modelRegistry") return Reflect.get(target, key);
      const registry = target.modelRegistry;
      return new Proxy(registry, {
        get(runtime, method) {
          if (method !== "streamSimple") return Reflect.get(runtime, method);
          return (model: any, context: any, options: any = {}) => {
            if (model.provider !== "github-copilot") return runtime.streamSimple(model, context, options);
            const { apiKey: _resolvedIdeToken, ...requestOptions } = options;
            return runtime.streamSimple(model, context, requestOptions);
          };
        },
      });
    },
  });
}

// Load the pinned upstream extension exactly once. Capture only its documented
// watchdog command; use its real review engine, cancellation and loop guards.
// This adapter never edits global settings during a task.
export function createSelectiveExtension(registerUpstream: (pi: ExtensionAPI) => void) {
  return function (pi: ExtensionAPI) {
    if (process.env.PI_SUBAGENT_CHILD === "1") return;
    const policy = new ComplexityPolicy();
    let watchdogCommand: ((args: string, ctx: ExtensionCommandContext) => Promise<void>) | undefined;
    let quiet = false;
    let commandOutput = "";
    let currentContext: ExtensionContext | undefined;
    let appliedModel: string | null | undefined;
    let queue = Promise.resolve();
    let generation = 0;
    const workflowRoots = new Set<string>();
    const errorResults = new Set<string>();

    const wrapped = new Proxy(pi, {
      get(target, key) {
        if (key === "on") return (name: string, handler: any) => {
          // Upstream registers its review boundary before our observers. A child
          // start can queue activation in the same tick; finish it before the
          // real review engine inspects enabled state or records the turn delta.
          if (name === "agent_end" || name === "turn_end") {
            return (target.on as any)(name, async (event: any, ctx: ExtensionContext) => {
              await queue;
              return handler(event, requestTimeAuthContext(ctx));
            });
          }
          return (target.on as any)(name, (event: any, ctx: ExtensionContext) => handler(event, requestTimeAuthContext(ctx)));
        };
        if (key === "registerCommand") return (name: string, command: any) => {
          if (name === "subagents-watchdog") {
            const handler = (args: string, ctx: ExtensionCommandContext) => command.handler(args, requestTimeAuthContext(ctx));
            watchdogCommand = handler;
            return target.registerCommand(name, { ...command, handler });
          }
          return target.registerCommand(name, command);
        };
        if (key === "sendMessage") return (message: any, options: any) => {
          if (quiet && typeof message.content === "string" && message.content.startsWith("Subagent watchdog")) {
            commandOutput = message.content;
            return;
          }
          return target.sendMessage(message, options);
        };
        return Reflect.get(target, key);
      },
    });
    registerUpstream(wrapped);
    if (!watchdogCommand) throw new Error("pi-subagents did not register its watchdog command. Check the pinned package before upgrading.");

    async function invoke(command: string, ctx: ExtensionContext) {
      quiet = true;
      commandOutput = "";
      try {
        // These command branches use only ordinary ExtensionContext fields;
        // they never call command-only navigation, reload, or waitForIdle APIs.
        await watchdogCommand!(command, ctx as ExtensionCommandContext);
        if (command.startsWith("session model ") && !commandOutput.startsWith("Subagent watchdog session model:")) {
          throw new Error(commandOutput || "Watchdog model selection failed.");
        }
      } finally { quiet = false; }
    }

    function update(ctx: ExtensionContext) {
      const epoch = generation;
      const next = queue.then(async () => {
        if (epoch !== generation) return;
        const desired = policy.desired();
        if (desired === appliedModel) return;
        if (desired) {
          await invoke(`session model ${desired}:high`, ctx);
          if (!appliedModel) await invoke("session on", ctx);
        } else await invoke("session off", ctx);
        appliedModel = desired;
        ctx.ui.setStatus("complex-watchdog", desired ? `Watchdog: ${desired === SOL ? "Sol 6.1" : "Luna 6"}` : undefined);
        if (desired) ctx.ui.notify(`Watchdog active: ${desired === SOL ? "Sol 6.1" : "Luna 6"} (${policy.tools} tools, ${policy.delegates} subagents).`, "info");
      });
      queue = next.catch((error) => {
        ctx.ui.notify(`Complex watchdog: ${error instanceof Error ? error.message : String(error)}`, "error");
      });
      return next;
    }

    function reset() {
      generation++;
      policy.resetTask();
      workflowRoots.clear();
      errorResults.clear();
    }

    pi.on("session_start", async (_event, ctx) => {
      currentContext = ctx;
      reset();
      policy.mode = "auto";
      appliedModel = undefined;
      await update(ctx);
    });
    pi.on("input", async (event, ctx) => {
      currentContext = ctx;
      // Async completion wakes are extension input, not new user tasks. Preserve
      // monitoring while a multi-agent task returns background results.
      if (event.source !== "extension" && !event.text.trimStart().startsWith("/")) {
        reset();
        await update(ctx);
      }
    });
    pi.on("before_agent_start", (event, ctx) => {
      currentContext = ctx;
      event.systemPromptOptions.sections.complex_watchdog_policy = [
        "The user authorizes bounded subagent delegation for long, difficult work; do simple tasks directly.",
        "Selective Watchdog: automatically enables GPT-6 Luna (high) after 3 dispatched/started subagents or 25 substantive tool calls.",
        "It escalates to GPT-6.1 Sol (high) after 8 subagents, or 60 substantive tools with 3 failed tool results.",
        "For a clearly difficult task, use complex_watchdog(action='luna') early; use action='sol' if Luna review is insufficient or risks require it.",
        "Manual luna/sol/off modes last for this session; action='auto' restores selective behavior.",
        "Keep review read-only, verify findings, run actual tests, and do not claim tests passed without execution.",
        "Use the pi-subagents skill for the installed delegation API; older tasks/chain examples may need scripted workflows.",
      ].join("\n");
    });
    pi.on("tool_execution_start", async (event, ctx) => {
      currentContext = ctx;
      policy.recordTool(event.toolCallId, event.toolName, event.args);
      await update(ctx);
    });
    pi.on("tool_result", async (event, ctx) => {
      if (event.isError && !errorResults.has(event.toolCallId)) {
        errorResults.add(event.toolCallId);
        policy.failures++;
        await update(ctx);
      }
    });
    const stopWorkflowListener = pi.events.on("subagent:async-started", (event: any) => {
      if (event.mode === "workflow" && typeof event.id === "string") workflowRoots.add(event.id);
    });
    const stopChildListener = pi.events.on("subagent:child-status", (event: any) => {
      if (event.status !== "started" || !workflowRoots.has(event.runId) || !currentContext) return;
      policy.recordChild(event.runId, event.childId);
      void update(currentContext).catch(() => {}); // update already reports the failure.
    });
    pi.on("session_shutdown", () => {
      generation++;
      stopWorkflowListener();
      stopChildListener();
      currentContext = undefined;
    });

    async function control(action: string, ctx: ExtensionContext) {
      if (action !== "status") {
        if (!["auto", "off", "luna", "sol"].includes(action)) throw new Error("Use status, auto, off, luna, or sol.");
        policy.mode = action;
        await update(ctx);
      }
      return `${policy.status()}; active reviewer: ${appliedModel ?? "off"}`;
    }
    pi.registerCommand("complex-watchdog", {
      description: "Selective reviews: status, auto, off, luna, or sol (session only)",
      handler: async (args, ctx) => { ctx.ui.notify(await control(args.trim() || "status", ctx), "info"); },
    });
    pi.registerTool({
      name: "complex_watchdog",
      label: "Complex task watchdog",
      description: "Inspect selective Watchdog or request Luna/Sol review for difficult work. No settings-file changes. auto restores complexity-triggered review; off suppresses it for this session.",
      parameters: Type.Object({ action: Type.Union(["status", "auto", "off", "luna", "sol"].map((value) => Type.Literal(value))) }),
      async execute(_id, args: { action: string }, _signal, _onUpdate, ctx) {
        return { content: [{ type: "text", text: await control(args.action, ctx) }], details: { mode: policy.mode, model: appliedModel } };
      },
    });
  };
}

export default createSelectiveExtension(registerSubagents);
