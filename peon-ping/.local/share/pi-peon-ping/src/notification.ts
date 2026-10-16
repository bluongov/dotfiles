import { execFileSync, execSync, spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { DATA_DIR } from "./constants";
import { detectPlatform, type Platform } from "./platform";

export const DEFAULT_ICON_PATH = join(DATA_DIR, "peon-icon.png");

export type Notifier = "osascript" | "notify-send" | "powershell";

export interface NotifyCommand {
  bin: string;
  args: string[];
}

function defaultCommandExists(cmd: string): boolean {
  try {
    execSync(`command -v ${cmd}`, { stdio: "pipe" });
    return true;
  } catch {
    return false;
  }
}

export function escapeNotificationText(text: string): string {
  return text.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

function escapePowerShellString(text: string): string {
  return text.replace(/'/g, "''");
}

export function detectNotifier(
  platform: Platform = detectPlatform(),
  commandExists: (cmd: string) => boolean = defaultCommandExists,
): Notifier | null {
  switch (platform) {
    case "mac":
      return "osascript";
    case "linux":
      return commandExists("notify-send") ? "notify-send" : null;
    case "wsl":
      return "powershell";
    default:
      return null;
  }
}

export function resolveIcon(packPath?: string): string {
  if (packPath) {
    const packIcon = join(packPath, "icon.png");
    if (existsSync(packIcon)) return packIcon;
  }
  return DEFAULT_ICON_PATH;
}

export function buildNotifyCommand(
  notifier: Notifier | string,
  title: string,
  body: string,
  iconPath?: string,
): NotifyCommand | null {
  const safeTitle = escapeNotificationText(title);
  const safeBody = escapeNotificationText(body);

  switch (notifier) {
    case "osascript": {
      const script = `display notification "${safeBody}" with title "${safeTitle}"`;
      return { bin: "osascript", args: ["-e", script] };
    }
    case "notify-send": {
      const args = [];
      if (iconPath) args.push(`--icon=${iconPath}`);
      args.push(title, body);
      return { bin: "notify-send", args };
    }
    case "powershell": {
      let iconXml = "";
      if (iconPath) {
        const winPath = escapePowerShellString(iconPath.replace(/\//g, "\\"));
        iconXml = `\n$binding = $template.GetElementsByTagName('binding').Item(0)\n$img = $template.CreateElement('image')\n$img.SetAttribute('placement','appLogoOverride')\n$img.SetAttribute('src','${winPath}')\n[void]$binding.AppendChild($img)`;
      }
      const psTitle = escapePowerShellString(title);
      const psBody = escapePowerShellString(body);
      const ps = `
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# A custom sender must have a Windows app identity; WSL does not register one.
$appId = 'peon-ping'
$appKey = 'HKCU:\\Software\\Classes\\AppUserModelId\\' + $appId
if (-not (Test-Path $appKey)) {
  New-Item -Path $appKey -Force > $null
  New-ItemProperty -Path $appKey -Name DisplayName -Value 'Pi - GLaDOS' -PropertyType String -Force > $null
  New-ItemProperty -Path $appKey -Name ShowInSettings -Value 1 -PropertyType DWord -Force > $null
}
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null
$template = [Windows.Data.Xml.Dom.XmlDocument]::new()
$template.LoadXml('<toast><visual><binding template="ToastGeneric"><text></text><text></text></binding></visual></toast>')
$text = $template.GetElementsByTagName('text')
[void]$text.Item(0).AppendChild($template.CreateTextNode('${psTitle}'))
[void]$text.Item(1).AppendChild($template.CreateTextNode('${psBody}'))${iconXml}
$audio = $template.CreateElement('audio')
$audio.SetAttribute('silent','true')
[void]$template.DocumentElement.AppendChild($audio)
$toast = [Windows.UI.Notifications.ToastNotification]::new($template)
$toast.Tag = 'pi-ready'
$toast.Group = 'pi-agent'
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)
if ($notifier.Setting.ToString() -ne 'Enabled') {
  throw ('Windows notifications for Pi are ' + $notifier.Setting.ToString())
}
$notifier.Show($toast)
`.trim();
      return { bin: "powershell.exe", args: ["-NoProfile", "-NonInteractive", "-Command", ps] };
    }
    default:
      return null;
  }
}

export interface NotifyOptions {
  platform?: Platform;
  iconPath?: string;
}

export function sendDesktopNotification(
  title: string,
  body: string,
  options: NotifyOptions | Platform = {},
): boolean {
  const opts: NotifyOptions = typeof options === "string"
    ? { platform: options }
    : options;
  const platform = opts.platform ?? detectPlatform();
  const notifier = detectNotifier(platform);
  if (!notifier) return false;

  let iconPath = opts.iconPath;
  if (platform === "wsl" && iconPath) {
    try {
      const windowsPath = execFileSync("wslpath", ["-w", iconPath], { encoding: "utf8" }).trim();
      if (windowsPath) iconPath = windowsPath;
      else {
        console.error("[peon-ping] wslpath returned an empty Windows icon path; sending toast without an icon");
        iconPath = undefined;
      }
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      console.error(`[peon-ping] Failed to convert notification icon path with wslpath: ${detail}`);
      iconPath = undefined;
    }
  }

  const cmd = buildNotifyCommand(notifier, title, body, iconPath);
  if (!cmd) return false;

  try {
    const child = spawn(cmd.bin, cmd.args, { stdio: "ignore", detached: true });
    child.on("error", (error) => {
      console.error(`[peon-ping] Failed to start desktop notifier '${cmd.bin}': ${error.message}`);
    });
    child.on("close", (code, signal) => {
      if (code !== 0 && code !== null) {
        console.error(`[peon-ping] Desktop notifier '${cmd.bin}' exited with code ${code}${signal ? ` (signal ${signal})` : ""}`);
      }
    });
    child.unref();
    return true;
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    console.error(`[peon-ping] Failed to start desktop notifier '${cmd.bin}': ${detail}`);
    return false;
  }
}
