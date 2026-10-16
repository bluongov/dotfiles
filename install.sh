#!/usr/bin/env bash
#
# install.sh — Symlink dotfiles into $HOME using GNU Stow.
#
# Usage:
#   ./install.sh                          # Install the default modules
#   ./install.sh zsh tmux                 # Install specific modules only
#   ./install.sh etraid_linter_formatter  # Opt-in (work) module
#
# Each top-level directory is a module whose contents mirror $HOME.
# For every file a module provides, this script:
#   1. creates the parent directory in $HOME (so stow links files, not dirs,
#      where the directory already holds machine-local state)
#   2. backs up a conflicting real file to <file>.backup.<timestamp>
#   3. runs `stow -R` for the module
#
# Remove symlinks:  stow -D <module>   (from ~/dotfiles)

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(readlink -f "$DOTFILES_DIR")"
TARGET_DIR="$(readlink -f "$HOME")"

# Default modules. Opt-in modules (not listed): etraid_linter_formatter
ALL_MODULES=(zsh tmux git nvim pi peon-ping k9s htop lazygit tealdeer nextjs-nodejs turborepo)

if [ "$#" -gt 0 ]; then MODULES=("$@"); else MODULES=("${ALL_MODULES[@]}"); fi

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[x]${NC} $*"; }

if ! command -v stow &>/dev/null; then
    warn "GNU Stow not found. Installing..."
    sudo apt-get update -qq && sudo apt-get install -y -qq stow
fi

STAMP="$(date +%Y%m%d%H%M%S)"

# Directories linked as a whole (new files created there land in the repo).
# Every other file gets its parent directory created first, so stow links the
# file itself and machine-local state next to it stays out of the repo.
FOLD_DIRS=(
    .config/nvim
    .pi/agent/agents
    .pi/agent/prompts
    .pi/agent/extensions
    .local/share/pi-peon-ping
)

in_fold_dir() {
    local rel="$1" d
    for d in "${FOLD_DIRS[@]}"; do
        [[ "$rel" == "$d/"* ]] && return 0
    done
    return 1
}

prepare_module() {
    local module="$1" file rel target
    while IFS= read -r -d '' file; do
        rel="${file#"$DOTFILES_DIR/$module/"}"
        case "$rel" in
            .stow-local-ignore|README.md|restore-on-start.sh|test-workspaces.py) continue ;;
            */node_modules/*|*/bun.lock) continue ;;
        esac
        target="$TARGET_DIR/$rel"
        # Already resolves to this repo file. Stow only owns relative links,
        # so replace an absolute one (made by hand) and let stow recreate it.
        if [ "$(readlink -f "$target" 2>/dev/null)" = "$file" ]; then
            [ -L "$target" ] && [[ "$(readlink "$target")" == /* ]] && rm "$target"
            continue
        fi
        if in_fold_dir "$rel"; then
            local fold
            for fold in "${FOLD_DIRS[@]}"; do
                [[ "$rel" == "$fold/"* ]] || continue
                if [ -e "$TARGET_DIR/$fold" ] && [ ! -L "$TARGET_DIR/$fold" ]; then
                    warn "  Backing up $TARGET_DIR/$fold -> $TARGET_DIR/$fold.backup.$STAMP"
                    mv "$TARGET_DIR/$fold" "$TARGET_DIR/$fold.backup.$STAMP"
                fi
                mkdir -p "$(dirname "$TARGET_DIR/$fold")"
            done
            continue
        fi
        mkdir -p "$(dirname "$target")"
        if [ -e "$target" ] || [ -L "$target" ]; then
            warn "  Backing up $target -> $target.backup.$STAMP"
            mv "$target" "$target.backup.$STAMP"
        fi
    done < <(find "$DOTFILES_DIR/$module" -type f -print0)
}

for module in "${MODULES[@]}"; do
    if [ ! -d "$DOTFILES_DIR/$module" ]; then
        warn "Module '$module' not found, skipping."
        continue
    fi
    info "Stowing: $module"
    prepare_module "$module"
    stow -R -d "$DOTFILES_DIR" -t "$TARGET_DIR" "$module" 2> >(grep -v 'BUG in find_stowed_path' >&2)
done

# ssh refuses group/world-writable config.
[ -d "$HOME/.ssh" ] && chmod 700 "$HOME/.ssh"
mkdir -p "$HOME/.ssh/config.d" && chmod 700 "$HOME/.ssh/config.d"

echo ""
info "Done. Conflicting files were backed up with .backup.$STAMP"
info "Next: open a new shell (exec zsh) and run 'tmux', then prefix + I for plugins."
