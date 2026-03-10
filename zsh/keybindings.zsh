# Vi mode fixes
bindkey "^?" backward-delete-char

# No delay after pressing escape
export KEYTIMEOUT=1

# smart shift+J: collapse backslash-continued lines
_smart_join() {
  if [[ "$BUFFER" != *$'\\\n'* ]]; then
    zle .vi-join
    return
  fi

  _collapse() {
    local out="" rest="$1"
    while [[ "$rest" == *$'\\\n'* ]]; do
      local chunk="${rest%%$'\\\n'*}"
      rest="${rest#*$'\\\n'}"
      rest="${rest#"${rest%%[! $'\t']*}"}"        # strip leading whitespace
      chunk="${chunk%"${chunk##*[! $'\t']}"}"      # strip trailing whitespace
      out+="${chunk} "
    done
    out+="$rest"
    print -rn -- "$out"
  }

  local new_buf before_cur
  new_buf="$(_collapse "$BUFFER")"
  before_cur="$(_collapse "${BUFFER[1,$CURSOR]}")"

  BUFFER="$new_buf"
  CURSOR=${#before_cur}
}

zle -N _smart_join
bindkey -M vicmd 'J' _smart_join
