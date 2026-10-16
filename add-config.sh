#!/usr/bin/env bash
#
# add-config.sh — Add a config file to dotfiles and create a symlink back.
#
# Usage:
#   ./add-config.sh ~/.config/newapp/config.yaml
#   ./add-config.sh ~/.zshrc
#
# What it does:
#   1. Figures out the module name from the file path
#   2. Creates the mirrored directory structure inside ~/dotfiles/<module>/
#   3. Moves the file into the repo (preserving its content)
#   4. Runs stow to create the symlink back to the original location
#   5. Registers the module in install.sh (ALL_MODULES) if it isn't already there
#
# After running this, edit the file at its original path as normal.
# Changes land in the repo automatically via the symlink.
# Commit with: dotfiles-sync

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Colors ───────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[x]${NC} $*" >&2; }
heading() { echo -e "\n${CYAN}==> $*${NC}"; }

# ── Usage check ──────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <path-to-config-file>"
    echo ""
    echo "Examples:"
    echo "  $0 ~/.config/newapp/config.yaml"
    echo "  $0 ~/.zshrc"
    exit 1
fi

# ── Resolve the input path ───────────────────────────────────────────────
# Expand ~ and resolve to absolute path
INPUT_PATH="${1/#\~/$HOME}"

if [[ ! -e "$INPUT_PATH" ]]; then
    error "File not found: $INPUT_PATH"
    exit 1
fi

if [[ -L "$INPUT_PATH" ]]; then
    RESOLVED="$(readlink -f "$INPUT_PATH")"
    # Check if it already points into dotfiles
    if [[ "$RESOLVED" == "$DOTFILES_DIR"* ]]; then
        info "Already tracked: $INPUT_PATH -> $RESOLVED"
        exit 0
    fi
    warn "$INPUT_PATH is a symlink to $RESOLVED (not in dotfiles). Proceeding anyway."
fi

# ── Derive module name ───────────────────────────────────────────────────
# Strategy: use the first path segment after ~/.config/ as the module name,
# or for files directly in $HOME (like .zshrc), prompt the user.

REL_PATH="${INPUT_PATH#$HOME/}"   # e.g. ".config/k9s/config.yaml" or ".zshrc"

if [[ "$REL_PATH" == .config/* ]]; then
    # e.g. .config/newapp/config.yaml  ->  module = newapp
    MODULE=$(echo "$REL_PATH" | cut -d'/' -f2)
else
    # File is directly in $HOME (e.g. .zshrc, .tmux.conf)
    # Use the filename without leading dot as default module name
    DEFAULT_MODULE="${REL_PATH#.}"   # strip leading dot
    DEFAULT_MODULE="${DEFAULT_MODULE%%.*}"  # strip extension
    echo ""
    echo "  File is directly in \$HOME: ~/$REL_PATH"
    echo "  What module name should it belong to? (default: $DEFAULT_MODULE)"
    read -r -p "  Module name: " MODULE
    MODULE="${MODULE:-$DEFAULT_MODULE}"
fi

if [[ -z "$MODULE" ]]; then
    error "Could not determine module name."
    exit 1
fi

# ── Confirm with user ────────────────────────────────────────────────────
heading "Plan"
echo "  Source file : $INPUT_PATH"
echo "  Module name : $MODULE"
echo "  Repo path   : $DOTFILES_DIR/$MODULE/$REL_PATH"
echo "  Symlink at  : $INPUT_PATH  ->  $DOTFILES_DIR/$MODULE/$REL_PATH"
echo ""
read -r -p "Proceed? [Y/n] " CONFIRM
CONFIRM="${CONFIRM:-Y}"
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    warn "Aborted."
    exit 0
fi

# ── Create module directory structure ────────────────────────────────────
REPO_FILE_PATH="$DOTFILES_DIR/$MODULE/$REL_PATH"
REPO_DIR="$(dirname "$REPO_FILE_PATH")"

heading "Creating repo directory"
mkdir -p "$REPO_DIR"
info "  $REPO_DIR"

# ── Move the file into the repo ──────────────────────────────────────────
heading "Moving file into repo"
mv "$INPUT_PATH" "$REPO_FILE_PATH"
info "  Moved to $REPO_FILE_PATH"

# ── Ensure the parent dir in $HOME exists (so stow symlinks the file, not the dir) ──
LIVE_PARENT="$(dirname "$INPUT_PATH")"
if [[ "$LIVE_PARENT" != "$HOME" ]]; then
    mkdir -p "$LIVE_PARENT"
    info "  Ensured $LIVE_PARENT exists"
fi

# ── Stow the module ───────────────────────────────────────────────────────
heading "Stowing module: $MODULE"
cd "$DOTFILES_DIR"
stow --restow --target="$HOME" "$MODULE"
info "  Symlink created: $INPUT_PATH -> $REPO_FILE_PATH"

# ── Register in install.sh ────────────────────────────────────────────────
heading "Updating install.sh"

# 1. Add module to ALL_MODULES if not already present
if grep -q "\b$MODULE\b" "$DOTFILES_DIR/install.sh"; then
    info "  Module '$MODULE' already in ALL_MODULES"
else
    sed -i "s/^ALL_MODULES=(\(.*\))/ALL_MODULES=(\1 $MODULE)/" "$DOTFILES_DIR/install.sh"
    info "  Added '$MODULE' to ALL_MODULES"
fi

# install.sh finds files, creates parent dirs and backs up conflicts by itself.

# ── Done ─────────────────────────────────────────────────────────────────
echo ""
info "Done! '$INPUT_PATH' is now tracked in dotfiles."
info ""
info "Next steps:"
info "  - Edit $INPUT_PATH as usual — changes go directly into the repo"
info "  - When ready to save: dotfiles-sync"
