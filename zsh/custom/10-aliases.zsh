# Loaded automatically from $ZSH_CUSTOM by Oh My Zsh.

# Modern CLI replacements.
(( $+commands[bat] )) && alias cat="bat --style=plain --paging=never"

if (( $+commands[eza] )); then
  alias ls="eza --icons=auto"
  alias ll="eza --long --color=always --color-scale --icons --group-directories-first --group --git --time-style=long-iso"
  alias la="eza --long --color=always --color-scale --icons --group-directories-first --group --git --time-style=long-iso --all"
  alias lt="eza --icons --tree"
fi

(( $+commands[htop] )) && alias top="htop"

if (( $+commands[nvim] )); then
  alias vi="nvim"
  alias vim="nvim"
  alias v="nvim"
fi
