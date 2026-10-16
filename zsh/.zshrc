# Lean Zsh: native completion plus only the integrations used here.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_SAVE_NO_DUPS

mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
autoload -Uz compinit
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"

export PATH="$HOME/.local/bin:$PATH"

# Fuzzy finder: Ctrl-R history, Ctrl-T files, Alt-C directories.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}' --preview-window right:60%:border-left --height=90% --border"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=3 --icons=always --color=always {}' --preview-window right:50%:border-left"
if [[ -t 0 && -t 1 ]] && command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
fi

# Keep autosuggestions without loading the Oh My Zsh framework.
[[ -r "$HOME/.config/zsh/plugins/zsh-autosuggestions.zsh" ]] && source "$HOME/.config/zsh/plugins/zsh-autosuggestions.zsh"

# Simple directory navigation.
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Compact file-listing aliases.
alias ls='eza --git'
alias lh='eza --icons -a --git'
alias ll='eza -lgh --icons --git'
alias la='eza -lah --icons --git'
alias l=la
alias lt='eza --tree --level=2 --icons --git'
alias ltgi='eza --tree --level=3 --icons --git-ignore'
alias cat='bat'
alias nokubectl='minikube kubectl --'
alias kmongo='kubectl port-forward -n databases mongodbssd-0 27017:27017'

# The one Oh My Zsh git shortcut used regularly in shell history.
gpsup() {
  local branch
  branch=$(command git branch --show-current) || return
  [[ -n "$branch" ]] || return 1
  command git push --set-upstream origin "$branch"
}

# Search file contents interactively with a preview.
fr() {
  rg --column --line-number --no-heading --color=always --smart-case -- "$*" | fzf --ansi \
    --delimiter : \
    --preview 'bat --color=always --style=numbers --line-range={2}:500 {1}' \
    --preview-window 'right:60%:+{2}-10'
}

# NVM and Node globals.
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
if command -v node >/dev/null 2>&1; then
  export NODE_PATH="$NVM_DIR/versions/node/$(node -v)/lib/node_modules${NODE_PATH:+:$NODE_PATH}"
fi

# Bun.
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"

# Python environments.
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"
  eval "$(pyenv virtualenv-init - zsh)"
fi

# Rust.
[[ -r "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# Go.
export GOROOT=/usr/local/go
export GOPATH="$HOME/go"
export PATH="$PATH:$GOROOT/bin:$GOPATH/bin"

# Private credentials are kept outside the dotfiles repository.
for _secret_file in "$HOME"/.config/secrets/*.zsh(N); do
  source "$_secret_file"
done
unset _secret_file

# VS Code terminal integration (only when launched from VS Code).
if [[ "$TERM_PROGRAM" == "vscode" ]] && command -v code >/dev/null 2>&1; then
  _vscode_zsh_integration="$(code --locate-shell-integration-path zsh 2>/dev/null)"
  [[ -r "$_vscode_zsh_integration" ]] && source "$_vscode_zsh_integration"
  unset _vscode_zsh_integration
fi

# Dotfiles helpers.
dotfiles-sync() {
  local dotfiles_dir="$HOME/dotfiles"
  echo ""
  echo "==> Staging all changes in $dotfiles_dir"
  git -C "$dotfiles_dir" add -A
  echo ""
  git -C "$dotfiles_dir" status
  echo ""
  read -r "msg?Commit message (leave blank to skip commit): "
  if [[ -n "$msg" ]]; then
    git -C "$dotfiles_dir" commit -m "$msg"
    echo ""
    echo "Done. Run 'git push' inside ~/dotfiles to push to remote."
  else
    echo "Staged but not committed. Run 'git commit' inside ~/dotfiles when ready."
  fi
}

add-config() {
  "$HOME/dotfiles/add-config.sh" "$@"
}

# Small cross-shell prompt, limited to useful project/environment context.
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  PROMPT='%F{cyan}%~%f %# '
fi
