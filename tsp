#!/usr/bin/env bash

# terminal constants
COLS=$(tput cols)
LINES=$(tput lines)
ESC=$'\x1b'

# frames
LOGO="
<l>
<l>  _____ _______   __  ___                     ___
<l> |_   _|_   _\ \ / / / __|_ __  __ _ __ ___  | _ \_ _ ___  __ _ _ _ __ _ _ __
<l>   | |   | |  \ V /  \__ \ \'_ \/ _\` / _/ -_) |  _/ \'_/ _ \/ _\` | \'_/ _\` | \'  \\
<l>   |_|   |_|   |_|   |___/ .__/\__,_\__\___| |_| |_| \___/\__, |_| \__,_|_|_|_|
<l>                         |_|                              |___/
<l>
"

CARRIER_BLOCK="
<l> _________▐▌
<l> |\/|____████
<l> |/\|   ▐████▌
<l> |\/|___██████
<l> |/\|   ██████
<l> |\/|   ██████
<l> |\/|   ██████
<l> |/\|   ██████
<l> |\/|  ▐██████▌
<l> |/\|  ████████
<l> |\/|   /\  /\\
<b1>
<b2>
"

CARRIERS=('
<l> _________▐▌
<l> |\/|____████
<l> |/\|   ▐████▌
<l> |\/|___██████
<l> |/\|   ██████
<l> |\/|   ██████
<l> |\/|   ██████
<l> |/\|   ██████
<l> |\/|  ▐██████▌
<l> |/\|  ████████
<l> |\/|   /\  /\\
'

'


<l>       /\
<l>      |  |
<l>     /    \
<l>    | O  O |
<l>    |      |
<l>    ========
<l>    /\/\/\/\
<l> _____________
<l> ||         ||
'

'
<l>       |
<l>     |||||
<l>      |||
<l>      |||
<l>     || ||
<l>     |   |
<l>    /     \
<l>    ========
<l>    /\/\/\/\
<l> _____________
<l> ||         ||
'
)


START_BUTTON='< Start Game >'
SELECT_BUTTON='< Select Carrier >'

# rendering variables
MODE=0
ACTIVE_BUTTON=0
ACTIVE_CARRIER=0
UPDATE_MENU=1
UPDATE_BUTTONS=1
UPDATE_CARRIER=

# helpers
repeat() {
    local times=$1
    local text=$2
    for _ in $(seq "$times"); do echo -n "$text"; done
}

fatal() {
    printf "[error]" "$@" >&2
    exit 1
}

cleanup() {
    printf "${ESC}[?1049l"
    printf "${ESC}[?25h"
}

calc_d() {
    local expr=${1:-0}
    awk "BEGIN {printf \"%d\n\", $expr }"
}

active_mode() {
    case "$((MODE % 2))" in
        0) echo -n 'menu';;
        1 | -1) echo -n 'gameplay';;
    esac
}

active_button() {
    case "$((ACTIVE_BUTTON % 2))" in
        0) echo -n 'start';;
        1 | -1) echo -n 'select';;
    esac
}

active_carrier() {
    local length=${#CARRIERS[@]}
    local index=$((ACTIVE_CARRIER % length))
    echo "${CARRIERS[$index]}"
}

# drawing
render_buttons() {
    local start_line=$1
    local indent=$2

    local start_button_line=$((start_line + 4))
    local start_button_col=$((indent + 2))

    local select_button_line=$((start_line + 7))
    local select_button_col=$((indent))

    local start_esc=
    local select_esc=
    if [[ $(active_button) == 'start' ]]; then
        start_esc="${ESC}[48;5;255m${ESC}[38;5;243m${ESC}[1m"
    else
        select_esc="${ESC}[48;5;255m${ESC}[38;5;243m${ESC}[1m"
    fi

    tput cup "$start_button_line" "$start_button_col"
    printf "%s%s${ESC}[0m" "$start_esc" "$START_BUTTON"

    tput cup "$select_button_line" "$select_button_col"
    printf "%s%s${ESC}[0m" "$select_esc" "$SELECT_BUTTON"
}

render_carriers() {
   local start_line=$1
   local start_indent=$2

   for i in {0..11}; do
       tput cup "$((start_line + i))" 0
       printf "$(repeat $((start_indent + 17)) ' ')"
   done

   tput cup "$start_line" 0
   f=$(active_carrier)
   f=${f//<l>/$(repeat $start_indent ' ')}
   printf "$f"
}

render_menu() {
    local carrier_indent=$(calc_d "$COLS / 2.3")
    local carrier_line=$(calc_d "$LINES / 1.5")

    if [[ -n $UPDATE_MENU ]]; then
        clear
        local logo_line=$((LINES / 6))
        local logo_indent=$(calc_d "$COLS / 3.77")
        tput cup "$logo_line" 0
        local l=$LOGO
        l=${l//<l>/$(repeat $logo_indent ' ')}
        printf "$l"

        tput cup "$carrier_line" 0
        local f=$CARRIER_BLOCK
        f=${f//<b1>/$(repeat $COLS '_')}
        f=${f//<b2>/$(repeat $COLS '/')}
        f=${f//<l>/$(repeat $carrier_indent ' ')}

        printf "$f"
        UPDATE_MENU=
    fi

    if [[ -n $UPDATE_BUTTONS ]]; then
        render_buttons $(calc_d "$LINES / 2.6") $(calc_d "$COLS / 2.35")
        UPDATE_BUTTONS=
    fi

    if [[ -n $UPDATE_CARRIER ]]; then
        render_carriers "$carrier_line" "$carrier_indent"
        UPDATE_CARRIER=
    fi

    tput cup 0 0
}


main() {

    # ensure we are called interactively
    if [[ ! -t 1 ]]; then
        fatal 'stdout must be a terminal. Run game in interactive mode'
    fi

    # configure terminal for drawing
    trap cleanup exit
    printf "${ESC}[?1049h"
    printf "${ESC}[?25l"

    local escape_char=$'\u1b'
    while true; do
        render_menu

        local cols=$(tput cols)
        if (( cols != COLS )); then
            UPDATE_MENU=1
            COLS=$cols
        fi

        local lines=$(tput lines)
        if (( lines != LINES )); then
            UPDATE_MENU=1
            LINES=$lines
        fi

        local input=
        read -rsn1 input < /dev/tty 2>/dev/null
        if [[ $input == "$escape_char" ]]; then
            read -rsn2 input < /dev/tty 2>/dev/null
        fi

        case "$input" in
            # key up
            '[A' | k | w)
                ((ACTIVE_BUTTON++))
                UPDATE_BUTTONS=1
                ;;

            # key down
            '[B' | j | s)
                ((ACTIVE_BUTTON--))
                UPDATE_BUTTONS=1
                ;;

            # key left
            '[D' | h | a)
                if [[ "$(active_button)" == 'select' ]]; then
                    ((ACTIVE_CARRIER++))
                    UPDATE_CARRIER=1
                fi
                ;;

            # key right
            '[C' | l | d)
                if [[ "$(active_button)" == 'select' ]]; then
                    ((ACTIVE_CARRIER--))
                    UPDATE_CARRIER=1
                fi
                ;;

            # key enter
            '')
                continue;; # for now skip

            # ignore everything else
            *) continue;;
        esac

    done
}

main
