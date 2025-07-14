HISTFILE=~/.config/zsh/.zsh_history
HISTSIZE=65536
SAVEHIST=65536

eval "$(direnv hook zsh)"

# asdf completion

fpath=(${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)

# initialise completions with ZSH's compinit
autoload -Uz compinit && compinit

