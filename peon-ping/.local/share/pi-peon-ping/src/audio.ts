import { execFileSync, spawn } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { mkdirSync, renameSync, statSync, unlinkSync } from "node:fs";
import { join, resolve } from "node:path";
import { DATA_DIR } from "./constants";
import { detectLinuxPlayer, detectPlatform, type Platform } from "./platform";
import { saveState } from "./config";
import { resolveIcon, sendDesktopNotification } from "./notification";
import { getPacksDir, pickSound } from "./packs";
import { getRelayUrl, relayPlayCategory, relayNotify } from "./relay";
import type { PeonConfig, PeonState } from "./types";

const PLATFORM: Platform = detectPlatform();

let currentSoundPid: number | null = null;
let playbackGeneration = 0;

export function killPreviousSound(): void {
  playbackGeneration++;
  if (currentSoundPid !== null) {
    try {
      process.kill(currentSoundPid);
    } catch {}
    currentSoundPid = null;
  }
}

function clampVolume(volume: number): number {
  return Number.isFinite(volume) ? Math.max(0, Math.min(1, volume)) : 0;
}

function processError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

interface ProcessResult {
  stdout: string;
  stderr: string;
}

function runTrackedProcess(
  bin: string,
  args: string[],
  generation: number,
  captureStdout = false,
): Promise<ProcessResult> {
  return new Promise((resolveProcess, rejectProcess) => {
    if (generation !== playbackGeneration) {
      rejectProcess(new Error("Playback cancelled"));
      return;
    }

    let child: ReturnType<typeof spawn>;
    try {
      child = spawn(bin, args, {
        stdio: ["ignore", captureStdout ? "pipe" : "ignore", "pipe"],
        detached: true,
      });
    } catch (error) {
      rejectProcess(error);
      return;
    }

    let stdout = "";
    let stderr = "";
    let settled = false;
    if (child.pid !== undefined) currentSoundPid = child.pid;

    child.stdout?.on("data", (chunk: Buffer | string) => {
      stdout = (stdout + chunk.toString()).slice(-8192);
    });
    child.stderr?.on("data", (chunk: Buffer | string) => {
      stderr = (stderr + chunk.toString()).slice(-8192);
    });

    const finish = (error?: Error, result?: ProcessResult) => {
      if (settled) return;
      settled = true;
      if (currentSoundPid === child.pid) currentSoundPid = null;
      if (error) rejectProcess(error);
      else resolveProcess(result ?? { stdout, stderr });
    };

    child.on("error", (error) => finish(error));
    child.on("close", (code, signal) => {
      if (generation !== playbackGeneration) {
        finish(new Error("Playback cancelled"));
      } else if (code !== 0) {
        const detail = stderr.trim() ? `: ${stderr.trim()}` : "";
        finish(new Error(`${bin} exited with ${code === null ? `signal ${signal}` : `code ${code}`}${detail}`));
      } else {
        finish(undefined, { stdout, stderr });
      }
    });
    child.unref();
  });
}

async function getCachedWslWav(file: string, volume: number, generation: number): Promise<string> {
  const absoluteFile = resolve(file);
  const inputStats = statSync(absoluteFile);
  const key = createHash("sha256")
    .update(`${absoluteFile}\0${inputStats.mtimeMs}\0${inputStats.size}\0${volume}`)
    .digest("hex");
  const cacheDir = join(DATA_DIR, "audio-cache");
  const outputFile = join(cacheDir, `${key}.wav`);
  mkdirSync(cacheDir, { recursive: true });

  try {
    if (statSync(outputFile).size > 44) return outputFile;
    unlinkSync(outputFile);
  } catch {}

  const tempFile = join(cacheDir, `${key}.${process.pid}.${randomUUID()}.tmp.wav`);
  try {
    await runTrackedProcess("ffmpeg", [
      "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
      "-i", absoluteFile,
      "-vn", "-af", `volume=${volume}`,
      "-acodec", "pcm_s16le", "-ar", "44100", "-ac", "2",
      "-f", "wav", tempFile,
    ], generation);
    if (generation !== playbackGeneration) throw new Error("Playback cancelled");
    if (statSync(tempFile).size <= 44) throw new Error("ffmpeg produced an empty WAV file");

    try {
      if (statSync(outputFile).size > 44) {
        unlinkSync(tempFile);
        return outputFile;
      }
    } catch {}
    renameSync(tempFile, outputFile);
    return outputFile;
  } finally {
    try {
      unlinkSync(tempFile);
    } catch {}
  }
}

async function playWslSound(file: string, volume: number, generation: number): Promise<void> {
  try {
    const wavFile = await getCachedWslWav(file, volume, generation);
    if (generation !== playbackGeneration) return;

    const windowsPath = execFileSync("wslpath", ["-w", wavFile], { encoding: "utf8" }).trim();
    if (!windowsPath) throw new Error("wslpath returned an empty Windows path");
    if (generation !== playbackGeneration) return;

    const quotedPath = windowsPath.replace(/'/g, "''");
    const script = `
      $ErrorActionPreference = 'Stop'
      $player = New-Object System.Media.SoundPlayer
      try {
        $player.SoundLocation = '${quotedPath}'
        $player.Load()
        $player.PlaySync()
      } finally {
        $player.Dispose()
      }
    `;
    await runTrackedProcess("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", script], generation);
  } catch (error) {
    if (generation === playbackGeneration) {
      console.error(`[peon-ping] WSL audio playback failed for '${file}': ${processError(error)}`);
    }
  }
}

export function playSound(file: string, volume: number): void {
  killPreviousSound();
  const safeVolume = clampVolume(volume);
  const generation = playbackGeneration;

  if (PLATFORM === "wsl") {
    void playWslSound(file, safeVolume, generation);
    return;
  }

  let child: ReturnType<typeof spawn> | undefined;

  switch (PLATFORM) {
    case "mac":
      child = spawn("afplay", ["-v", String(safeVolume), file], {
        stdio: "ignore",
        detached: true,
      });
      break;

    case "linux": {
      const player = detectLinuxPlayer();
      if (!player) return;

      switch (player) {
        case "pw-play":
          child = spawn("pw-play", ["--volume", String(safeVolume), file], {
            stdio: "ignore", detached: true,
          });
          break;
        case "paplay": {
          const paVol = Math.round(safeVolume * 65536);
          child = spawn("paplay", [`--volume=${paVol}`, file], {
            stdio: "ignore", detached: true,
          });
          break;
        }
        case "ffplay": {
          const ffVol = Math.round(safeVolume * 100);
          child = spawn("ffplay", ["-nodisp", "-autoexit", "-volume", String(ffVol), file], {
            stdio: "ignore", detached: true,
          });
          break;
        }
        case "mpv": {
          const mpvVol = Math.round(safeVolume * 100);
          child = spawn("mpv", ["--no-video", `--volume=${mpvVol}`, file], {
            stdio: "ignore", detached: true,
          });
          break;
        }
        case "play":
          child = spawn("play", ["-v", String(safeVolume), file], {
            stdio: "ignore", detached: true,
          });
          break;
        case "aplay":
          child = spawn("aplay", ["-q", file], {
            stdio: "ignore", detached: true,
          });
          break;
      }
      break;
    }
  }

  if (child) {
    const started = child;
    started.on("error", (error) => {
      console.error(`[peon-ping] Failed to start audio player '${started.spawnfile}': ${error.message}`);
      if (currentSoundPid === started.pid) currentSoundPid = null;
    });
    started.on("close", (code, signal) => {
      if (currentSoundPid === started.pid) currentSoundPid = null;
      if (code !== 0 && code !== null) {
        console.error(`[peon-ping] Audio player '${started.spawnfile}' exited with code ${code}${signal ? ` (signal ${signal})` : ""}`);
      }
    });
    started.unref();
    currentSoundPid = started.pid ?? null;
  }
}

export type UiNotify = (message: string, type?: "info" | "warning" | "error") => void;

export function sendNotification(
  title: string,
  body: string,
  config: PeonConfig,
  uiNotify?: UiNotify,
): void {
  if (!config.desktop_notifications) return;

  const relayUrl = getRelayUrl(config.relay_mode);
  if (relayUrl) {
    relayNotify(relayUrl, title, body).catch(() => {});
    return;
  }

  const packPath = join(getPacksDir(), config.default_pack);
  const iconPath = resolveIcon(packPath);
  const sent = sendDesktopNotification(title, body, { iconPath });
  if (!sent && uiNotify) {
    uiNotify(`${title}: ${body}`, "info");
  }
}

export function playCategorySound(category: string, config: PeonConfig, state: PeonState): void {
  if (!config.enabled || state.paused) return;
  if (!config.categories[category]) return;

  const relayUrl = getRelayUrl(config.relay_mode);
  if (relayUrl) {
    relayPlayCategory(relayUrl, category).catch(() => {});
    return;
  }

  const sound = pickSound(category, config, state);
  if (sound) {
    playSound(sound.file, config.volume);
    saveState(state);
  }
}
