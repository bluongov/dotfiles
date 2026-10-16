#!/usr/bin/env python3
"""Test startup/restore safely using private snapshots, sockets, and /bin/sh panes."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

HOME = Path.home()
SOURCE = HOME / ".local/share/tmux/resurrect"
CONFIG = HOME / "dotfiles/tmux/.tmux.conf"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


with tempfile.TemporaryDirectory(prefix="tmux-startup-check-") as root:
    root = Path(root)
    copies = root / "snapshots"
    copies.mkdir()
    for name in ("last", "pane_contents.tar.gz"):
        shutil.copy2(SOURCE / name, copies / name)
    socket = str(root / "default")
    config = root / "test.conf"
    text = CONFIG.read_text().replace(
        "'~/.local/share/tmux/resurrect'", repr(str(copies))
    ).replace("set -g @popup-autostart on", "set -g @popup-autostart off")
    config.write_text(
        "set -g default-shell /bin/sh\n"
        "set -g @resurrect-processes false\n"
        "set -g history-limit 50000\n" + text
    )

    def tmux(*args):
        return subprocess.check_output(
            ["tmux", "-S", socket, *args], text=True, stderr=subprocess.PIPE
        ).strip()

    def stop():
        subprocess.run(
            ["tmux", "-S", socket, "kill-server"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        # kill-server returns before socket teardown on some tmux versions.
        for _ in range(50):
            if not Path(socket).exists():
                break
            time.sleep(0.1)

    def wait_status(wanted):
        for _ in range(150):
            state = tmux("show-option", "-gqv", "@workspace-startup-status")
            if state == wanted:
                return
            time.sleep(0.1)
        raise AssertionError(f"Expected {wanted}, got {state}")

    try:
        expected = {}
        for line in (copies / "last").read_text().splitlines():
            fields = line.split("\t")
            if fields[0] == "pane":
                address = f"{fields[1]}:{fields[2]}.{fields[5]}"
                expected[address] = fields[7][1:]
        expected_sessions = {address.split(":")[0] for address in expected}
        saved_digest = digest(copies / "last")
        for iteration in range(2):
            tmux("-f", str(config), "new-session", "-d", "-s", "0", "-x", "269", "-y", "66")
            wait_status("ready")
            sessions = set(tmux("list-sessions", "-F", "#{session_name}").splitlines())
            assert sessions == expected_sessions, sessions
            actual = dict(row.split("\t") for row in tmux(
                "list-panes", "-a", "-F",
                "#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_path}",
            ).splitlines())
            assert actual == expected, (actual, expected)
            assert tmux("show-option", "-gqv", "@continuum-save-interval") == "5"
            assert digest(copies / "last") == saved_digest, "Recovery snapshot overwritten"
            assert tmux("show-option", "-gqv", "status-right").count("continuum_save.sh") == 1
            before = tmux("list-panes", "-a", "-F", "#{pane_id} #{pane_pid}")
            tmux("source-file", str(config))
            time.sleep(0.2)
            assert tmux("list-panes", "-a", "-F", "#{pane_id} #{pane_pid}") == before
            print(f"PASS startup/restart {iteration + 1}: sessions/panes/directories restored, "
                  "reload idempotent, recovery snapshot untouched.")
            stop()

        # Deliberately impossible pane index in the PRIVATE snapshot only.
        lines = (copies / "last").read_text().splitlines()
        for index, line in enumerate(lines):
            fields = line.split("\t")
            if fields[0] == "pane":
                fields[5] = "999"
                lines[index] = "\t".join(fields)
                break
        (copies / "last").write_text("\n".join(lines) + "\n")
        broken_digest = digest(copies / "last")
        tmux("-f", str(config), "new-session", "-d", "-s", "0", "-x", "269", "-y", "66")
        wait_status("failed")
        assert tmux("show-option", "-gqv", "@continuum-save-interval") == "0"
        tmux("source-file", str(config))
        time.sleep(0.2)
        assert tmux("show-option", "-gqv", "@continuum-save-interval") == "0"
        assert digest(copies / "last") == broken_digest
        print("PASS failure safety: incomplete restore pauses autosave, even after reload.")
    finally:
        stop()

print("Temporary servers/files removed; live sessions were never stopped or restored.")
