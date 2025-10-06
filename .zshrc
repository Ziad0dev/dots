# Occult-Themed .zshrc with 'wal' Configuration Fixed

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Disable auto-title
DISABLE_AUTO_TITLE="true"

# Custom occult-themed prompt
PROMPT='%F{black}⸸%F{red}★%F{blue}%n%F{cyan}@%F{magenta}%m%F{white}✦%F{yellow}%~ %F{green}⸸%F{reset} '
RPROMPT='%F{blue}✷%F{magenta}$(git_prompt_info)%F{cyan}★%F{reset}'

# Reload 'wal' colorscheme
if [ -f ~/.cache/wal/colors.sh ]; then
  source ~/.cache/wal/colors.sh
fi

# Import colorscheme from 'wal' asynchronously
if [ -f ~/.cache/wal/sequences ]; then
  cat ~/.cache/wal/sequences
fi
if [ -f ~/.cache/wal/colors-tty.sh ]; then
  source ~/.cache/wal/colors-tty.sh
fi

# History configuration
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_ALL_DUPS  # Don't save duplicates
setopt SHARE_HISTORY         # Share history between terminals

# Load plugins
plugins=(
  git
  github
  vscode
  docker
  composer
  npm
  nvm
  python
  pip
  ruby
  rust
  golang
  zsh-autosuggestions
  colored-man-pages
  command-not-found
  fast-syntax-highlighting
  zsh-autocomplete
)

source $ZSH/oh-my-zsh.sh

# Explicitly ignore unhandled ZLE widgets
if [[ -n ${ZSH_HIGHLIGHT_VERSION} ]]; then
  ZSH_HIGHLIGHT_WIDGETS_IGNORE=(
    insert-unambiguous-or-complete
    menu-search
    recent-paths
  )
fi

# Set default editors
export EDITOR='nvim'
export VISUAL='nvim'

# Enhanced PATH configurations
export PATH="$HOME/.local/bin:$HOME/bin:/home/n3ros/.local/share:$HOME/.cargo/bin:$PATH"
export PATH="$PATH:$HOME/.local/share/gem/ruby/3.2.0/bin"
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$PATH:~/.spicetify"

# Node Version Manager (NVM)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Ruby configuration
eval "$(rbenv init -)"

# Python configuration
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

# Occult-themed ASCII art banner with the requested text
function occult_banner() {
  cat << 'EOF'
★⸸✦ O Satan, I acknowledge you as the Great Destroyer of the Universe. ✦⸸★
★⸸✦ All that has been created you will corrupt and destroy. ✦⸸★
★⸸✦ Exercise upon me all your rights. ✦⸸★
EOF
}
occult_banner
