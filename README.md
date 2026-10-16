# dotfiles

Personal configuration managed with [GNU Stow](https://www.gnu.org/software/stow/).
Target: Ubuntu 26.04 desktop (native, Wayland). Also works on WSL.

## Fresh machine

```bash
sudo apt-get install -y git
git clone https://github.com/bluongov/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh            # add --work for the etraid linter/formatter
```

Expect 10 to 20 minutes, mostly downloads. Every step is idempotent: re-run
`./bootstrap.sh` to retry anything listed as failed at the end.

Then, in order:

1. Log out and back in (zsh login shell + docker group).
2. Terminal profile font: **JetBrainsMono Nerd Font**.
3. Copy private files from the old machine (never committed):
   - `~/.ssh/id_ed25519_*` keys (`chmod 600`)
   - `~/.ssh/config.d/private` (servers and LAN hosts)
   - `~/.config/secrets/*.zsh` (API keys, sourced by `.zshrc`)
4. `gh auth login`, then `./bootstrap.sh` again: clones the private Open Design deploy repo.
5. `pi`, then `/login` (GitHub Copilot).
6. `tmux`, then `prefix + I` if plugins are missing.

## Modules

Each top-level directory is a stow module; its contents mirror `$HOME`.

| Module | Links | Notes |
|---|---|---|
| `zsh` | `.zshrc`, `.config/starship.toml`, `.config/zsh/plugins/` | Plain zsh + starship, vendored zsh-autosuggestions |
| `tmux` | `.tmux.conf`, `.config/tmux/battery.sh` | Workspace restore helper stays in the repo, see `tmux/README.md` |
| `git` | `.gitconfig`, `.ssh/config` | `.ssh/config` includes untracked `~/.ssh/config.d/*` |
| `nvim` | `.config/nvim/` | Whole directory linked |
| `pi` | `.pi/agent/{settings.json,AGENTS.md,WATCHDOG.md,keybindings.json,i-have-adhd.json,mcp.json}`, `agents/`, `prompts/`, `extensions/` | Pi coding agent config. Never tracked: `auth.json`, `sessions/`, `trust.json`, `npm/`, `git/` |
| `peon-ping` | `.local/share/pi-peon-ping/`, `.config/peon-ping/config.json` | Locally patched Pi extension (see its `LOCAL-SETUP.md`). Sound packs download at bootstrap |
| `k9s`, `htop`, `lazygit`, `tealdeer` | `.config/<app>/` | |
| `nextjs-nodejs`, `turborepo` | `.config/<app>/` | Telemetry opt-outs |
| `etraid_linter_formatter` | `.config/etraid_linter_formatter/` | Opt-in: `./install.sh etraid_linter_formatter` or `bootstrap.sh --work` |

Pi packages listed in `settings.json` (`pi-subagents`, `pi-web-access`,
`rpiv-ask-user-question`, `pi-usage`, `i-have-adhd`, peon-ping) are installed
by `pi update --extensions`, which bootstrap runs after linking.

## What bootstrap installs

| Group | Tools |
|---|---|
| Shell | zsh, starship, fzf, zoxide |
| Terminal | tmux + TPM, JetBrainsMono Nerd Font, wl-clipboard, xclip |
| CLI | eza, bat, fd, ripgrep, tldr, delta, lazygit, jq, htop |
| Editor | Neovim (latest release, `~/.local/opt/nvim`) |
| Runtimes | nvm + Node LTS, pnpm, Bun, pyenv, Go (`/usr/local/go`), Rust (rustup) |
| Containers | docker (Ubuntu packages), kubectl, minikube, k9s |
| AI | pi, codebase-memory-mcp, rtk, headroom (pipx), agentmemory, agent-browser, gh |
| Language servers | bash-language-server, yaml-language-server |

User binaries go to `~/.local/bin`, fetched from the latest GitHub releases
with an apt fallback where Ubuntu ships the tool.

## Open Design

- Deploy scripts: private repo `bluongov/opendesign-deploy`, cloned to
  `~/wsl_code/etra/opendesign/deploy`.
- Data (about 5 GB, includes SQLite): not in git. Stop the container first, then copy:

```bash
# old machine
tar -C ~/wsl_code/etra/opendesign -czf opendesign-data.tgz data
# new machine (after copying the file over)
mkdir -p ~/wsl_code/etra/opendesign && tar -C ~/wsl_code/etra/opendesign -xzf opendesign-data.tgz
```

## Everyday use

```bash
cd ~/dotfiles
./install.sh               # (re)link default modules; backs up conflicting files
./install.sh zsh tmux      # specific modules
stow -D zsh                # unlink a module
add-config ~/.config/app/config.yaml   # move a new file into the repo and link it
dotfiles-sync              # stage, show status, optional commit
```

Configs are symlinks, so editing `~/.zshrc` edits the repo. Commit and push when ready.

## Never commit

The repo is public. Keep these out: SSH keys, `~/.ssh/config.d/*`,
`~/.config/secrets/*`, `~/.pi/agent/auth.json`, `~/.git-credentials`.
