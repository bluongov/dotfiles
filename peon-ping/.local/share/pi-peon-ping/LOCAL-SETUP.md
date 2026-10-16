# Local pi-peon-ping setup

Installed from the published `pi-peon-ping@0.2.0` npm tarball, SHA-1 `1c03210112fe20d7ce259e0807c471902c295fa3`. Original MIT license is retained. This is a local compatibility-patched copy, not an unmodified npm installation.

## Local changes

- Uses current `@earendil-works/pi-coding-agent` / `pi-tui` imports and host peer dependencies.
- Completion alerts use `agent_settled`, so automatic retries and queued follow-ups finish first.
- Completion timing is process-local; another Pi session cannot suppress an alert through the shared five-second cooldown.
- WSL playback converts clips into cached, volume-adjusted PCM WAV files using `ffmpeg`, resolves their Windows paths with `wslpath`, and plays the entire clip with Windows `System.Media.SoundPlayer`. This avoids removed Windows Media Player components and the original three-second truncation.
- Windows popup text is PowerShell-escaped; toast sounds are silent to avoid mixing them with GLaDOS.
- Windows sender identity `peon-ping` is registered per-user at `HKCU:\Software\Classes\AppUserModelId\peon-ping` as `Pi - GLaDOS`. No global notification settings are changed. Uses the current `ToastGeneric` XML template instead of legacy `ToastText02`; Windows notification history was verified to contain the diagnostic popup.
- Uses `[void]` when appending WinRT XML nodes. Redirecting `AppendChild()` output to `$null` made PowerShell enumerate a changing collection and fail when adding the icon.
- Source backup before the Windows sender/template fix: `src/notification.ts.before-windows-registration`. The registry identity did not exist before setup.
- Verified the full icon-bearing popup path exits with status 0 and appears in Windows notification history. User confirmed seeing the desktop banner. All 86 tests passed.
- Adds `/peon test` and makes the settings-panel preview use completion sounds.
- Moves startup resource creation out of the extension factory into `session_start`.

## Configuration

`~/.config/peon-ping/config.json`: mj-grunts (was GLaDOS/Cortana), 50% volume, desktop notifications enabled, completion-only categories, local audio (no relay).

Pack: `~/.config/peon-ping/packs/glados`, official registry v1.0.0, 23 clips. Manifest SHA-256 `1e6066a66018f56092b917ae36123f84278b1fb29979642cee664760a1549d8b`. Sound pack license: CC-BY-NC-4.0; preserve manifest attribution.

Audio cache: `~/.config/peon-ping/audio-cache`.

## Use

- `/reload` in each existing Pi session loads the new extension.
- `/peon test`: completion clip and desktop popup.
- `/peon`: adjust volume, categories, pause playback, or select another installed pack.
- New sessions load it automatically.

## Maintenance

This local package is registered in personal Pi settings, outside any project repository. `pi update --extensions` does not replace the local source with the upstream npm package. Host-package symlinks under `node_modules/@earendil-works` support direct Bun testing; normal Pi loading supplies the host imports.

Reinstalling directly from npm would create another unpatched package, so do not install it alongside this one. For an update, review upstream changes and reapply the documented compatibility patches first.

Settings backup: `~/.pi/agent/backups/settings.before-peon-ping.20261006T145102Z.json`.

To disable this setup without removing other packages: `pi remove /home/bluongo/.local/share/pi-peon-ping`, then `/reload` in open sessions. The sound pack/configuration remain on disk.
