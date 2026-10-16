#!/usr/bin/env bash
#
# bootstrap.sh — Set up a fresh Ubuntu machine (target: Ubuntu 26.04 desktop).
#
# Idempotent: every section skips work that is already done, so re-run it
# after `gh auth login` to clone the private repos it skipped the first time.
#
# Usage:
#   ./bootstrap.sh          # personal setup
#   ./bootstrap.sh --work   # also stow + install the etraid linter/formatter
#
# Installs:
#   Shell      zsh, starship, zsh-autosuggestions (vendored), fzf, zoxide
#   Terminal   tmux + TPM, JetBrainsMono Nerd Font, wl-clipboard
#   CLI        eza, bat, fd, ripgrep, tldr, delta, lazygit, jq, htop
#   Editor     Neovim (latest release)
#   Runtimes   nvm + Node LTS, pnpm, Bun, pyenv, Go, Rust (rustup)
#   Containers docker, kubectl, minikube, k9s
#   AI         Pi coding agent + Pi packages, peon-ping sounds,
#              codebase-memory-mcp, rtk, headroom, agentmemory, agent-browser, gh
#   Projects   Open Design deploy repo (private, needs gh auth)

set -euo pipefail

WORK=false
for arg in "$@"; do
    case "$arg" in
        --work) WORK=true ;;
        -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$HOME/.cargo/bin:/usr/local/go/bin:$HOME/.bun/bin:$HOME/.pyenv/bin:$PATH"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[x]${NC} $*"; }
section() { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }
is_installed() { command -v "$1" &>/dev/null; }

FAILED=()
fail() { error "$1 failed"; FAILED+=("$1"); }

# ── Architecture names used by release assets ──────────────────────────
case "$(dpkg --print-architecture)" in
    amd64) X86=x86_64;  AMD=amd64 ;;
    arm64) X86=aarch64; AMD=arm64 ;;
    *) error "Unsupported architecture: $(dpkg --print-architecture)"; exit 1 ;;
esac

if grep -qi microsoft /proc/version 2>/dev/null; then
    warn "WSL detected. This script targets native Ubuntu; most steps still work."
fi

# ── GitHub release helper ────────────────────────────────────────────────
# install_release <binary> <owner/repo> <asset-regex>
# Downloads the latest release asset matching the regex, finds <binary> in it
# (tarball, zip or raw binary) and installs it into ~/.local/bin.
gh_api() {
    local auth=()
    [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    curl -fsSL "${auth[@]}" "https://api.github.com/repos/$1"
}

install_release() {
    local bin="$1" repo="$2" regex="$3" url tmp file found
    url=$(gh_api "$repo/releases/latest" \
        | jq -r --arg re "$regex" '[.assets[] | select(.name | test($re))][0].browser_download_url // empty') || return 1
    [ -n "$url" ] || { warn "No asset matching /$regex/ in $repo"; return 1; }
    tmp=$(mktemp -d)
    file="$tmp/$(basename "$url")"
    curl -fsSL "$url" -o "$file" || { rm -rf "$tmp"; return 1; }
    case "$file" in
        *.tar.gz|*.tgz) tar -xzf "$file" -C "$tmp" ;;
        *.zip)          unzip -q "$file" -d "$tmp" ;;
        *)              mv "$file" "$tmp/$bin" ;;
    esac
    found=$(find "$tmp" -type f -name "$bin" | head -1)
    [ -n "$found" ] || { warn "$bin not found inside $(basename "$url")"; rm -rf "$tmp"; return 1; }
    install -m 755 "$found" "$BIN_DIR/$bin"
    rm -rf "$tmp"
    info "$bin installed from $repo"
}

# tool <binary> <owner/repo> <asset-regex> [apt-fallback-package]
tool() {
    local bin="$1" repo="$2" regex="$3" apt_pkg="${4:-}"
    if is_installed "$bin"; then info "$bin already installed"; return 0; fi
    install_release "$bin" "$repo" "$regex" && return 0
    if [ -n "$apt_pkg" ]; then
        warn "Falling back to apt package $apt_pkg"
        sudo apt-get install -y -qq "$apt_pkg" && return 0
    fi
    fail "$bin"
}

# ── 1. System packages ───────────────────────────────────────────────────
section "System packages (apt)"
sudo apt-get update -qq
APT_PACKAGES=(
    git curl wget unzip rsync stow tmux zsh jq htop ca-certificates gnupg
    build-essential cmake pkg-config
    wl-clipboard xclip            # clipboard (Wayland first, X11 fallback)
    libnotify-bin pipewire-bin    # notify-send + pw-play for peon-ping
    fontconfig pipx
    # pyenv build dependencies
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev
    libncurses-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
)
sudo apt-get install -y -qq "${APT_PACKAGES[@]}" || {
    warn "Bulk install failed; retrying package by package"
    for p in "${APT_PACKAGES[@]}"; do sudo apt-get install -y -qq "$p" || fail "apt $p"; done
}

# ── 2. Zsh as login shell ────────────────────────────────────────────────
section "Zsh"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
    chsh -s "$(command -v zsh)" && warn "Login shell changed to zsh. Log out and back in."
else
    info "zsh is already the login shell"
fi

# ── 3. CLI tools (latest GitHub releases, apt fallback) ──────────────────
section "CLI tools"
tool bat      sharkdp/bat              "${X86}-unknown-linux-musl\\.tar\\.gz$"      bat
tool fd       sharkdp/fd               "${X86}-unknown-linux-musl\\.tar\\.gz$"      fd-find
tool rg       BurntSushi/ripgrep       "${X86}-unknown-linux-musl\\.tar\\.gz$"      ripgrep
tool fzf      junegunn/fzf             "linux_${AMD}\\.tar\\.gz$"                   fzf
tool eza      eza-community/eza        "^eza_${X86}-unknown-linux-(musl|gnu)\\.tar\\.gz$" eza
tool tldr     tealdeer-rs/tealdeer     "^tealdeer-linux-${X86}-musl$"               tealdeer
tool zoxide   ajeetdsouza/zoxide       "${X86}-unknown-linux-musl\\.tar\\.gz$"      zoxide
tool delta    dandavison/delta         "${X86}-unknown-linux-musl\\.tar\\.gz$"      git-delta
tool lazygit  jesseduffield/lazygit    "linux_${X86}\\.tar\\.gz$"
tool starship starship/starship        "^starship-${X86}-unknown-linux-musl\\.tar\\.gz$"

# apt names some tools differently; expose the usual names.
is_installed batcat && ! is_installed bat && ln -sf "$(command -v batcat)" "$BIN_DIR/bat"
is_installed fdfind && ! is_installed fd  && ln -sf "$(command -v fdfind)" "$BIN_DIR/fd"
is_installed tldr && { tldr --update >/dev/null 2>&1 || true; }

# ── 4. Neovim ────────────────────────────────────────────────────────────
section "Neovim"
if ! is_installed nvim; then
    NVIM_DIR="$HOME/.local/opt/nvim"
    if curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${X86/aarch64/arm64}.tar.gz" -o /tmp/nvim.tar.gz; then
        rm -rf "$NVIM_DIR" && mkdir -p "$NVIM_DIR"
        tar -xzf /tmp/nvim.tar.gz -C "$NVIM_DIR" --strip-components=1
        ln -sf "$NVIM_DIR/bin/nvim" "$BIN_DIR/nvim"
        rm -f /tmp/nvim.tar.gz
        info "Neovim installed: $("$BIN_DIR/nvim" --version | head -1)"
    else
        fail "neovim"
    fi
else
    info "Neovim already installed: $(nvim --version | head -1)"
fi

# ── 5. Nerd Font (icons in eza, starship, nvim) ──────────────────────────
section "JetBrainsMono Nerd Font"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
if [ ! -d "$FONT_DIR" ]; then
    mkdir -p "$FONT_DIR"
    if curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz \
        | tar -xJ -C "$FONT_DIR"; then
        fc-cache -f >/dev/null
        info "Font installed. Select 'JetBrainsMono Nerd Font' in your terminal profile."
    else
        rm -rf "$FONT_DIR"; fail "nerd font"
    fi
else
    info "Nerd Font already installed"
fi

# ── 6. Tmux Plugin Manager ───────────────────────────────────────────────
section "Tmux Plugin Manager"
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    git clone -q https://github.com/tmux-plugins/tpm "$TPM_DIR"
    "$TPM_DIR/bin/install_plugins" >/dev/null 2>&1 || warn "Run prefix + I inside tmux to install plugins"
else
    info "TPM already installed"
fi

# ── 7. Language runtimes ─────────────────────────────────────────────────
section "Runtimes"

# nvm + Node LTS
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    NVM_TAG=$(gh_api nvm-sh/nvm/releases/latest | jq -r .tag_name)
    PROFILE=/dev/null bash -c "$(curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_TAG}/install.sh")" || fail "nvm"
fi
# shellcheck disable=SC1091
set +u; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
if is_installed nvm && ! nvm ls --no-colors default >/dev/null 2>&1; then
    nvm install --lts && nvm alias default 'lts/*'
fi
set -u
is_installed node && info "Node $(node --version)"

# Bun
if ! is_installed bun; then
    curl -fsSL https://bun.sh/install | bash >/dev/null || fail "bun"
    export PATH="$HOME/.bun/bin:$PATH"
else
    info "Bun already installed"
fi

# pyenv (+ pyenv-virtualenv, used by .zshrc)
if [ ! -d "$HOME/.pyenv" ]; then
    curl -fsSL https://pyenv.run | bash >/dev/null || fail "pyenv"
else
    info "pyenv already installed"
fi

# Go
if [ ! -x /usr/local/go/bin/go ]; then
    GO_VERSION=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)
    if curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${AMD}.tar.gz" -o /tmp/go.tgz; then
        sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf /tmp/go.tgz && rm -f /tmp/go.tgz
        info "Go installed: $GO_VERSION"
    else
        fail "go"
    fi
else
    info "Go already installed: $(/usr/local/go/bin/go version)"
fi

# Rust
if ! is_installed rustup; then
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path >/dev/null || fail "rustup"
else
    info "Rust already installed"
fi

# ── 8. Containers + Kubernetes ───────────────────────────────────────────
section "Docker + Kubernetes"
if ! is_installed docker; then
    sudo apt-get install -y -qq docker.io docker-compose-v2 docker-buildx \
        || sudo apt-get install -y -qq docker.io || fail "docker"
fi
if is_installed docker && ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER" && warn "Added $USER to the docker group. Log out and back in."
fi

if ! is_installed kubectl; then
    K8S_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    curl -fsSL "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/${AMD}/kubectl" -o "$BIN_DIR/kubectl" \
        && chmod +x "$BIN_DIR/kubectl" && info "kubectl $K8S_VERSION installed" || fail "kubectl"
else
    info "kubectl already installed"
fi
if ! is_installed minikube; then
    curl -fsSL "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${AMD}" -o "$BIN_DIR/minikube" \
        && chmod +x "$BIN_DIR/minikube" && info "minikube installed" || fail "minikube"
else
    info "minikube already installed"
fi
tool k9s derailed/k9s "^k9s_Linux_${AMD}\\.tar\\.gz$"

# ── 9. GitHub CLI ────────────────────────────────────────────────────────
section "GitHub CLI"
if ! is_installed gh; then
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -qq && sudo apt-get install -y -qq gh || fail "gh"
else
    info "gh already installed"
fi

# ── 10. Dotfiles symlinks ────────────────────────────────────────────────
section "Dotfiles"
MODULES=()
$WORK && MODULES=(zsh tmux git nvim pi peon-ping k9s htop lazygit tealdeer nextjs-nodejs turborepo etraid_linter_formatter)
bash "$DOTFILES_DIR/install.sh" "${MODULES[@]}"

# ── 11. AI tooling ───────────────────────────────────────────────────────
section "AI tooling"
NPM_GLOBALS=(
    @earendil-works/pi-coding-agent   # pi
    pnpm
    @agentmemory/agentmemory
    agent-browser
    bash-language-server
    yaml-language-server
    wscat
)
if is_installed npm; then
    MISSING=()
    for pkg in "${NPM_GLOBALS[@]}"; do
        npm ls -g --depth=0 "$pkg" >/dev/null 2>&1 || MISSING+=("$pkg")
    done
    if [ "${#MISSING[@]}" -gt 0 ]; then
        npm install -g "${MISSING[@]}" || fail "npm globals"
    else
        info "npm globals already installed"
    fi
else
    fail "npm globals (npm missing)"
fi

tool codebase-memory-mcp DeusData/codebase-memory-mcp "^codebase-memory-mcp-linux-${AMD}\\.tar\\.gz$"
tool rtk rtk-ai/rtk "^rtk-${X86}-unknown-linux-musl\\.tar\\.gz$"

if ! is_installed headroom; then
    pipx install headroom-ai || fail "headroom"
else
    info "headroom already installed"
fi

# Pi packages declared in ~/.pi/agent/settings.json
if is_installed pi; then
    pi update --extensions || fail "pi packages"
fi

# peon-ping sound pack (downloaded, not committed: pack licenses vary)
PEON_PACK=$(jq -r '.default_pack' "$HOME/.config/peon-ping/config.json" 2>/dev/null || echo "")
if [ -n "$PEON_PACK" ] && [ ! -d "$HOME/.config/peon-ping/packs/$PEON_PACK/sounds" ] && is_installed bun; then
    info "Downloading peon-ping pack: $PEON_PACK"
    PEON_PACK="$PEON_PACK" bun -e '
        const m = await import(process.env.HOME + "/.local/share/pi-peon-ping/src/packs.ts");
        const ok = await m.downloadPack(process.env.PEON_PACK, await m.fetchRegistry(), console.log);
        process.exit(ok ? 0 : 1);
    ' || fail "peon-ping pack"
fi

# ── 12. Private project repos (need `gh auth login` first) ──────────────
section "Private repos"
OD_DIR="$HOME/wsl_code/etra/opendesign"
if [ -d "$OD_DIR/deploy/.git" ]; then
    info "Open Design deploy repo already cloned"
elif is_installed gh && gh auth status -h github.com >/dev/null 2>&1; then
    mkdir -p "$OD_DIR"
    gh repo clone bluongov/opendesign-deploy "$OD_DIR/deploy" || fail "opendesign-deploy clone"
else
    warn "Skipped Open Design: run 'gh auth login', then re-run ./bootstrap.sh"
fi

# ── 13. Work-only extras ─────────────────────────────────────────────────
if $WORK; then
    section "etraid linter/formatter"
    ETRAID_DIR="$HOME/.config/etraid_linter_formatter"
    if [ -f "$ETRAID_DIR/package.json" ] && [ ! -d "$ETRAID_DIR/node_modules" ]; then
        (cd "$ETRAID_DIR" && npm install) || fail "etraid npm install"
    fi
fi

# ── Summary ──────────────────────────────────────────────────────────────
section "Bootstrap complete"
if [ "${#FAILED[@]}" -gt 0 ]; then
    error "Failed steps (re-run ./bootstrap.sh to retry): ${FAILED[*]}"
else
    info "All steps succeeded."
fi
cat <<'EOF'

Manual steps:
  1. Log out and back in (zsh login shell + docker group)
  2. Terminal profile font -> "JetBrainsMono Nerd Font"
  3. Copy private files from the old machine:
       ~/.ssh/id_ed25519_* keys, ~/.ssh/config.d/private, ~/.config/secrets/*.zsh
  4. gh auth login, then re-run ./bootstrap.sh (clones Open Design deploy)
  5. pi, then /login for GitHub Copilot
  6. tmux, then prefix + I for plugins
EOF
