# # Setup fzf
# # ---------
# if [[ ! "$PATH" == */home/steph/.vim/plugged/fzf/bin* ]]; then
  # export PATH="${PATH:+${PATH}:}/home/steph/.vim/plugged/fzf/bin"
# fi
#
# # Auto-completion
# # ---------------
# [[ $- == *i* ]] && source "/home/steph/.vim/plugged/fzf/shell/completion.bash" 2> /dev/null

# Key bindings
# ------------
# source "/home/steph/.vim/plugged/fzf/shell/key-bindings.bash"
source /usr/share/doc/fzf/examples/key-bindings.bash

# my mods
#--------
export FZF_CTRL_R_OPTS="
  --bind 'ctrl-j:accept'"



