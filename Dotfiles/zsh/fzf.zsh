export FZF_DEFAULT_COMMAND="ag -l -g ''"
export FZF_DEFAULT_OPTS="--inline-info --ansi --cycle
                          --history=$HOME/.fzfhistory
                          --history-size=10000
                          --tiebreak=length
                          --color=bg+:0,hl:110,hl+:110
                          --color=prompt:110,marker:110,pointer:110,spinner:110,info:110"

# z with fzf
j() {
  if [[ -z "$*" ]]; then
    cd "$(_z -l 2>&1 | sed -n 's/^[ 0-9.,]*//p' | fzf --no-sort --tac --prompt='jump > ' --reverse)"
  else
    _z "$@"
  fi
}

# edit files in editor
fe() {
  fzf --multi --select-1 --exit-0 --query="$1" --prompt="files > " --reverse | tr "\n" "\0" | xargs -0 -o vim
}

# cd to directory
fcd() {
  local dir="$(find ${1:-*} -path '*/\.*' -prune -o -type d -print 2> /dev/null | fzf --select-1 --exit-0 --query="$1" --prompt='dir > ' --reverse)"
  [ -n "$dir" ] && cd "$dir"
}

# search through history
fh() {
  print -z $(fc -l 1 | fzf --tac --no-sort --nth=2.. --reverse --query="$1" --prompt="history > " --reverse | sed 's/ *[0-9]* *//')
}

# kill process
fkill() {
  ps -ef | sed 1d | fzf --multi --query="$1" --prompt="kill > " --reverse | awk '{ print $2 }' | xargs kill -${1:-9}
}

# find any file on disk
fl() {
  locate / | fzf --reverse --prompt='locate > '
}

# checkout git commit
fcom() {
  local commits=$(git ls --reverse)
  local commit=$(echo "$commits" | fzf --tac +s +m -e)

  git checkout $(echo "$commit" | sed "s/ .*//")
}

# checkout git branch (including remote)
fbr() {
  local branches=$(git branch --all | grep -v HEAD)
  local branch=$(echo "$branches" | fzf -d $(( 2 + $(wc -l <<< "$branches") )) +m)

  git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}
