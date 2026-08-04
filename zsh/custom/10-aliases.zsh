# OMZ가 $ZSH_CUSTOM/*.zsh 를 알파벳 순으로 자동 소싱한다.
# 플러그인 로드 후, 테마 로드 전에 실행되므로 플러그인 alias를 덮어쓸 수 있다.

# cat 대체
alias cat="bat --style=plain --paging=never"

# ls 대체
alias ls="eza --icons"
alias ll="eza --long --color=always --color-scale --icons --group-directories-first --group --git --time-style=long-iso"
alias la="eza --long --color=always --color-scale --icons --group-directories-first --group --git --time-style=long-iso --all"
alias lt="eza --icons --tree"

# top 대체
alias top="htop"

# vim 대체
alias vi="nvim"
alias vim="nvim"
alias v="nvim"
