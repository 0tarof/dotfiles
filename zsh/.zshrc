HISTFILE=~/.config/zsh/.zsh_history
HISTSIZE=65536
SAVEHIST=65536

# set path

typeset -U path PATH
path=(
$HOME/bin(N-/)
${ASDF_DATA_DIR:-$HOME/.asdf}/shims(N-/)
/opt/homebrew/opt/mysql-client@8.0/bin(N-/)
/opt/homebrew/bin(N-/)
/opt/homebrew/sbin(N-/)
/usr/local/bin(N-/)
/usr/local/sbin(N-/)
/usr/bin
/usr/sbin
/bin
/sbin
/Library/Apple/usr/bin
)

eval "$(direnv hook zsh)"

# asdf completion

fpath=(${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)

# initialise completions with ZSH's compinit
autoload -Uz compinit && compinit

