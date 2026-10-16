# tmux workspaces

Four sessions share the default tmux server and one Resurrect snapshot:

| Session | Starting directory / existing work | Switch inside tmux |
| --- | --- | --- |
| `COAGENT` | `~/wsl_docs/etra/coagent` | `Ctrl-a`, then `F1` or `F5` |
| `SWARMER` | Existing SWARMER windows and panes | `Ctrl-a`, then `F2` |
| `PhD` | `~/phd` | `Ctrl-a`, then `F3` |
| `misc` | Remaining windows from the former session `0` | `Ctrl-a`, then `F4` |

## Everyday use

- Start after reboot: run `tmux`, then wait a moment for recovery to finish.
- Switch sessions: `Ctrl-a`, then `s` (session tree), or `o` (SessionX).
- Detach without stopping programs: `Ctrl-a`, then `d`.
- Reattach to a running workspace: `tmux attach -t COAGENT` (or another name).
- Save all sessions now: `Ctrl-a`, then `Ctrl-s`.
- Restore manually: `Ctrl-a`, then `Ctrl-r`.
- Reload configuration: `Ctrl-a`, then `Shift-r`.
- TPM install/update: `Ctrl-a`, then `Shift-i` / `Shift-u`.

Continuum automatically saves **all sessions**, not just the attached one,
every five minutes while a main-server client displays the status bar.
Its status-bar timer does not run when all clients are detached; save manually
before detaching or shutting down if you need the latest changes captured.
No boot/login service was enabled.

## What is saved

Sessions, windows, pane layouts, working directories, and full terminal
scrollback are saved in `~/.local/share/tmux/resurrect/`; `last` points to the
current layout snapshot and `pane_contents.tar.gz` holds terminal text.

This is not a process checkpoint or a backup of project files. It does not
preserve arbitrary running jobs, SSH connections, Pi conversations, shell
variables, activated virtualenvs, or unsaved editor buffers. Resurrect retains
its conservative default program-restore allowlist; arbitrary commands are
not automatically rerun. Resume agents and reconnect SSH separately.
Snapshots may contain sensitive terminal output; the main snapshot directory
is private (mode 700).

## Configuration and popup isolation

Both `~/.tmux.conf` and `~/.config/tmux/tmux.conf` resolve to
`~/dotfiles/tmux/.tmux.conf`. TPM/plugins are in `~/.config/tmux/plugins/`.

Continuum loads after theme/status plugins and before popup autostart. An
explicit main-server save hook survives reloads even while the separate popup
server exists. Other sockets have automatic saving/restoration disabled and
separate manual snapshot directories (`resurrect-popup`, etc.).

`restore-on-start.sh` handles one-time default-server startup restoration:

1. Autosave is paused until the launcher's initial pane exists.
2. Recovery runs once, even if the popup server is already running.
3. Saved pane addresses are checked before five-minute autosave resumes.
4. Config reloads do not restore or restart existing work.

`@continuum-restore on` controls this helper. `@continuum-restore-max-delay 0`
disables Continuum's own startup detection to avoid a second restore and its
multi-server guard; the helper does the actual automatic Resurrect recovery.
`~/tmux_no_auto_restore` is still honored as an explicit opt-out.
`@workspace-save-interval` is the desired interval; `@continuum-save-interval`
is the effective interval (temporarily zero during recovery).

If startup restoration is incomplete, saving stays paused to protect the last
snapshot. Inspect the snapshot and restore missing work manually before marking
recovery complete and reloading:

```sh
tmux show-option -g @workspace-startup-status
tmux show-option -g @continuum-save-interval
# Only AFTER inspecting/recovering the missing work:
tmux set-option -g @workspace-startup-status ready
tmux source-file ~/.tmux.conf
```

## Safe verification

```sh
python3 ~/dotfiles/tmux/test-workspaces.py
```

The test uses private snapshot copies and temporary tmux sockets, with `/bin/sh`
only and program replay disabled. It checks startup, restart with other servers
present, idempotent reloads, and snapshot protection on incomplete restoration.
It never stops or restores the live sessions.

Original configs and snapshots were backed up before setup under:
`~/.local/state/tmux/setup-backup-20261006T135245/`.
