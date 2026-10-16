#!/usr/bin/env bash
# Own automatic restore on the default socket, even if the popup server survives.
# Saving stays paused until recovery completes. Wait for the launcher's initial
# session: tmux loads its config before executing the initial new-session command.
set -euo pipefail

socket=${TMUX%%,*}
[[ ${socket##*/} == default ]] || exit 0

started=$(tmux display-message -p '#{start_time}')
launched=$(date +%s)
# list-sessions can succeed with empty output before the initial session exists.
for ((attempt = 0; attempt < 100; attempt++)); do
    if [[ -n $(tmux list-panes -a -F '#{pane_id}' 2>/dev/null) ]]; then
        break
    fi
    sleep 0.1
done
if [[ -z $(tmux list-panes -a -F '#{pane_id}' 2>/dev/null) ]]; then
    tmux set-option -g @workspace-startup-status failed
    printf 'No initial tmux pane appeared; autosave remains paused.\n' >&2
    exit 1
fi

tmux wait-for -L workspace-startup
trap 'tmux wait-for -U workspace-startup' EXIT

status=$(tmux show-option -gqv @workspace-startup-status)
if [[ $status == ready ]]; then
    exit 0
elif [[ -n $status ]]; then
    # A failed/interrupted restore must never replace the recovery snapshot.
    tmux set-option -g @continuum-save-interval 0
    tmux display-message 'Workspace restore incomplete; autosave paused. Check the snapshot before retrying.'
    exit 1
fi

interval=$(tmux show-option -gqv @workspace-save-interval)
tmux set-option -g @continuum-save-interval 0
tmux set-option -g @continuum-save-last-timestamp "$(date +%s)"
tmux set-option -g @workspace-startup-status restoring

restore=$(tmux show-option -gqv @continuum-restore)
directory=$(tmux show-option -gqv @resurrect-dir)
directory=${directory/#\~/$HOME}

# Reloading the config in an established server must not restore old work.
if [[ $restore == on && ! -e $HOME/tmux_no_auto_restore &&
      $((launched - started)) -le 10 && -f $directory/last ]]; then
    "$HOME/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh"

    # Resurrect can exit successfully even when individual pane creation fails.
    # Verify all saved pane addresses exist before permitting automatic saving.
    missing=$(LC_ALL=C comm -23 \
        <(awk -F '\t' '$1 == "pane" {print $2 ":" $3 "." $6}' "$directory/last" | LC_ALL=C sort -u) \
        <(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}' | LC_ALL=C sort -u))
    if [[ -n $missing ]]; then
        tmux set-option -g @workspace-startup-status failed
        tmux display-message 'Workspace restore incomplete; autosave paused to protect the snapshot.'
        printf 'Missing restored panes:\n%s\n' "$missing" >&2
        exit 1
    fi
fi

tmux set-option -g @continuum-save-last-timestamp "$(date +%s)"
tmux set-option -g @workspace-startup-status ready
tmux set-option -g @continuum-save-interval "$interval"
