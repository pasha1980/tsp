#!/usr/bin/env bash

# terminal configs
COLS=$(tput cols)
LINES=$(tput lines)

# helpers
repeat() {
    local times=$1
    local text=$2
    for _ in $(seq "$times"); do echo -n "$text"; done
}

fatal() {
	tput setaf 1
	echo "[error]" "$@" >&2
	tput sgr0
	exit 1
}

# configure terminal for drawing
# cleanup() {
# 	tput rmcup
	# tput cnorm
# }
# trap cleanup exit
# tput smcup
# tput civis

# first screen
IFS=$'\0' read -r -d '' START_FRAME <<- "EOF"
(LEFT) _________/\
(LEFT) |\/|____/  \
(LEFT) |/\|   /    \
(LEFT) |\/|___|    |
(LEFT) |/\|___|    |
(LEFT) |\/|   |    |
(LEFT) |\/|   |    |
(LEFT) |/\|   |    |
(LEFT) |\/|  /      \
(LEFT) |/\|  | ____ |
(LEFT) |\/|   /\  /\
(BOTTOM)
EOF

main() {
	# ensure we are called interactively
	if [[ ! -t 1 ]]; then
		fatal 'stdout must be a terminal'
	fi

    # render start frame
    f="$START_FRAME"
    f=$(echo "$f" | sed "s/(BOTTOM)/$(repeat $COLS '-')/g")
    f=$(echo "$f" | sed "s/(LEFT)/$(repeat $(($COLS / 5)) ' ')/g")
    echo "$f"
}

main
