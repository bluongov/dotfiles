/**
 * peon-ping — Sound notifications for pi
 *
 * Plays themed audio clips on lifecycle events (session start, task ack,
 * task complete, permission needed). Uses peon-ping / OpenPeon sound packs.
 *
 * /peon opens a settings panel. /peon install downloads packs.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { basename } from "node:path";
import { playCategorySound, sendNotification } from "./audio";
import { ensureDirs, loadConfig, loadState, saveState } from "./config";
import { listPacks } from "./packs";
import { checkRelayHealth, detectRemoteSession, getRelayUrl, relaySetupInstructions } from "./relay";
import { createSettingsPanel, runInstall } from "./ui";

export default function (pi: ExtensionAPI) {
  let config = loadConfig();
  let state = loadState();
  let installing = false;
  let taskStartedAt = 0;

  const hasPacks = () => listPacks().length > 0;

  const shouldPlaySounds = (ctx: { hasUI: boolean; mode?: string }) => {
    if (!ctx.hasUI || (ctx.mode && ctx.mode !== "tui") || installing) return false;
    const relayUrl = getRelayUrl(config.relay_mode);
    return relayUrl !== null || hasPacks();
  };

  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI || ctx.mode !== "tui") return;
    ensureDirs();

    config = loadConfig();
    state = loadState();

    const relayUrl = getRelayUrl(config.relay_mode);
    if (relayUrl) {
      const healthy = await checkRelayHealth(relayUrl);
      if (!healthy) {
        const session = detectRemoteSession();
        const instructions = session
          ? relaySetupInstructions(session)
          : `Ensure relay is running at ${relayUrl}`;
        ctx.ui.notify(`peon-ping: relay unreachable at ${relayUrl}. ${instructions}`, "warning");
      }
    }

    if (!relayUrl && !hasPacks()) {
      ctx.ui.notify("peon-ping: no sound packs. Run /peon install", "warning");
      return;
    }

    state.session_start_time = Date.now();
    state.prompt_timestamps = [];
    saveState(state);

    playCategorySound("session.start", config, state);
  });

  pi.on("agent_start", async (_event, ctx) => {
    config = loadConfig();
    state = loadState();
    if (!shouldPlaySounds(ctx)) return;

    const now = Date.now();
    if (!taskStartedAt) taskStartedAt = now;
    const window = config.annoyed_window_seconds * 1000;
    state.prompt_timestamps = state.prompt_timestamps.filter((t) => now - t < window);
    state.prompt_timestamps.push(now);
    saveState(state);

    if (state.prompt_timestamps.length >= config.annoyed_threshold) {
      playCategorySound("user.spam", config, state);
    } else {
      playCategorySound("task.acknowledge", config, state);
    }
  });

  pi.on("tool_execution_end", async (event, ctx) => {
    if (!event.isError) return;

    config = loadConfig();
    state = loadState();
    if (!shouldPlaySounds(ctx)) return;

    playCategorySound("task.error", config, state);
  });

  // Settled is final: retries, compaction and queued follow-ups are finished.
  // Runtime task timing is per Pi process, not shared between concurrent sessions.
  pi.on("agent_settled", async (_event, ctx) => {
    const startedAt = taskStartedAt;
    taskStartedAt = 0;
    config = loadConfig();
    state = loadState();
    if (!startedAt || !shouldPlaySounds(ctx)) return;

    const now = Date.now();
    state.last_stop_time = now;

    const silentMs = config.silent_window_seconds * 1000;
    if (silentMs > 0 && now - startedAt < silentMs) return;

    saveState(state);
    playCategorySound("task.complete", config, state);

    if (config.enabled && !state.paused) {
      const project = basename(ctx.cwd);
      sendNotification(
        `pi · ${project}`,
        "Ready for input",
        config,
        ctx.hasUI ? ctx.ui.notify.bind(ctx.ui) : undefined,
      );
    }
  });

  pi.registerCommand("peon", {
    description: "peon-ping settings; /peon test previews the completion alert",
    handler: async (args, ctx) => {
      const sub = (args || "").trim();

      if (sub === "test") {
        ensureDirs();
        config = loadConfig();
        state = loadState();
        playCategorySound("task.complete", config, state);
        sendNotification(`pi · ${basename(ctx.cwd)}`, "GLaDOS notification test", config);
        ctx.ui.notify(`peon-ping: ${config.default_pack}, volume ${Math.round(config.volume * 100)}%`, "info");
        return;
      }

      if (sub === "install" || sub.startsWith("install ")) {
        const packNames = sub.replace(/^install\s*/, "").trim().split(/\s+/).filter(Boolean);
        await runInstall(
          packNames,
          ctx,
          () => { installing = true; },
          () => { installing = false; },
        );
        return;
      }

      config = loadConfig();

      if (!hasPacks() && !getRelayUrl(config.relay_mode)) {
        const ok = await ctx.ui.confirm(
          "peon-ping",
          "No sound packs installed. Download default packs now?",
        );
        if (ok) {
          await runInstall(
            [],
            ctx,
            () => { installing = true; },
            () => { installing = false; },
          );
        }
        return;
      }

      await ctx.ui.custom<void>(createSettingsPanel);
    },
  });
}
