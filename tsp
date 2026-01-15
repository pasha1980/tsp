#!/usr/bin/env bash

# ensure we are called interactively
if [[ ! -t 1 ]]; then
    echo '[error] stdout must be a terminal. Run game in interactive mode'
    exit 1
fi

# TODO: replace with ASCII seq
if ! tput cup 0 0 2>/dev/null; then
    echo '[error] tput is not installed. Please, install it with available package manager'
    exit 1
fi

# terminal constants
COLS=$(tput cols)
LINES=$(tput lines)
ESC=$'\x1b'
SHMID=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c 64; echo)
SHM=$(if [[ "$(uname -s)" == 'Darwin' ]]; then echo "/tmp/$SHMID"; else echo "/dev/shm/$SHMID"; fi)
CPIPE="/tmp/$SHMID.sock"
if [[ ! -p $CPIPE ]]; then
    mkfifo $CPIPE
fi

# frames
LOGO="
<l>  _____ _______   __  ___                     ___
<l> |_   _|_   _\ \ / / / __|_ __  __ _ __ ___  | _ \_ _ ___  __ _ _ _ __ _ _ __
<l>   | |   | |  \ V /  \__ \ \'_ \/ _\` / _/ -_) |  _/ \'_/ _ \/ _\` | \'_/ _\` | \'  \\
<l>   |_|   |_|   |_|   |___/ .__/\__,_\__\___| |_| |_| \___/\__, |_| \__,_|_|_|_|
<l>                         |_|                              |___/
"

SUFRACE_BLOCK="
<b1>
<b2>
"

CARRIERS=('
   ▐▌
  ████
 ▐████▌
 ██████
 ██████
 ██████
 ██████
 ██████
▐██████▌
████████
 /\  /\\
'

'




   /\
  |  |
 /    \
| O  O |
|      |
========
/\/\/\/\
'

'


   |
 |||||
  |||
  |||
 || ||
 |   |
/     \
========
/\/\/\/\
'
)


START_BUTTON='< Start Game >'
SELECT_BUTTON='< Select Carrier >'

# control variables (shared)
RENDERING_PID=

MODE=0
ACTIVE_BUTTON=0
ACTIVE_CARRIER=0

UPDATE_MENU=1
UPDATE_BUTTONS=1
UPDATE_CARRIER=1

# gameplay calculation variables
## total mass of the carrier
G_M1=
## fuel mass
G_M2=
## fuel mass consumption per iteration
G_deltaM=
## specific impulse of engine
G_I=
## local acceleration of gravity
G_g=
## the angle between the thrust vector and the gravity vector
G_psi=
## frontal aerodynamic drag force
G_A=
## engine thrust force
G_F=
## the angle between the thrust vector and the rocket's velocity
G_alpha=
## current rocket speed
G_V=0
## current rocket high
G_h=0

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
    if [[ -n $RENDERING_PID ]]; then
        kill "$RENDERING_PID"
    fi
    rm "$SHM"
    rm "$CPIPE"

    printf "${ESC}[?1049l"
    printf "${ESC}[?25h"
}

calc_d() {
    local expr=${1:-0}
    awk "BEGIN {printf \"%d\n\", $expr }"
}

active_mode() {
    local mode=$(get_shared | cut -d '|' -f 1)
    case "$((mode % 2))" in
        0) echo -n 'menu';;
        1 | -1) echo -n 'gameplay';;
    esac
}

active_button() {
    local active_btn=$(get_shared | cut -d '|' -f 2)
    case "$((active_btn % 2))" in
        0) echo -n 'start';;
        1 | -1) echo -n 'select';;
    esac
}

active_carrier() {
    local length=${#CARRIERS[@]}
    local active_carr=$(get_shared | cut -d '|' -f 3)
    local index=$((active_carr % length))
    echo "${CARRIERS[$index]}"
}

# shared memory
write_shared() {
    echo "$MODE|$ACTIVE_BUTTON|$ACTIVE_CARRIER|$COLS|$LINES" > "$SHM"
}

get_shared() {
    local res=$(cat "$SHM" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo "$res"
    fi
}

write_commands() {
    echo "$UPDATE_MENU|$UPDATE_BUTTONS|$UPDATE_CARRIER" > $CPIPE &
}

read_commands() {
    cat $CPIPE
}

# calculations
orbit_calc() {
    while true; do
        if [[ "$(active_mode)" == 'gameplay' ]]; then
            return 0
        fi

        #todo

    done
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

   readarray -t strs <<<"$(active_carrier)"
   for i in "${!strs[@]}"; do
       tput cup "$((start_line + i))" "$start_indent"
       printf "$(repeat 17 ' ')"
       tput cup "$((start_line + i))" "$start_indent"
       printf "${strs[$i]}"
   done
}

render_menu() {
    local comm=$(read_commands)
    local u_menu=$(echo "$comm"| cut -d '|' -f 1)
    local u_buttons=$(echo "$comm"| cut -d '|' -f 2)
    local u_carriers=$(echo "$comm"| cut -d '|' -f 3)

    local shared=$(get_shared)
    if [[ -z $shared ]]; then
        return 0
    fi

    local cols=$(echo "$shared" | cut -d '|' -f 4)
    local lines=$(echo "$shared" | cut -d '|' -f 5)


    if [[ -n $u_menu ]]; then
        clear
        local logo_line=$((lines / 6))
        local logo_indent=$(calc_d "$cols / 3.77")
        tput cup "$logo_line" 0
        local l=$LOGO
        l=${l//<l>/$(repeat $logo_indent ' ')}
        printf "$l"

        tput cup $(calc_d "$lines / 1.1") 0
        local f=$SUFRACE_BLOCK
        f=${f//<b1>/$(repeat $cols '_')}
        f=${f//<b2>/$(repeat $cols '/')}

        printf "$f"
    fi

    if [[ -n $u_buttons ]]; then
        render_buttons $(calc_d "$lines / 2.6") $(calc_d "$cols / 2.35")
    fi

    if [[ -n $u_carriers ]]; then
        local carrier_indent=$(calc_d "$cols / 2.2")
        local carrier_line=$(calc_d "$lines / 1.5")
        render_carriers "$carrier_line" "$carrier_indent"
    fi

    tput cup 0 0
}

render_gameplay() {
    local shared=$(get_shared)
    if [[ -z $shared ]]; then
        return 0
    fi

    local cols=$(echo "$shared" | cut -d '|' -f 4)
    local lines=$(echo "$shared" | cut -d '|' -f 5)

    # show surface if we need
    local surface_height=$(calc_d "$lines - ($lines / 1.1)")
    if (( (G_h + (lines / 3)) < surface_height )); then
        tput cup "$(($lines - $surface_height))" 0
        local f=$SUFRACE_BLOCK
        f=${f//<b1>/$(repeat $cols '_')}
        f=${f//<b2>/$(repeat $cols '/')}
        printf "$f"
    fi



}

render() {
    while true; do
        case "$(active_mode)" in
            menu) render_menu;;
            gameplay) render_gameplay;;
        esac
    done
}

main() {
    # configure terminal for drawing
    trap cleanup exit
    printf "${ESC}[?1049h"
    printf "${ESC}[?25l"

    local escape_char=$'\u1b'

    write_shared
    render &
    RENDERING_PID=$!

    write_commands

    while true; do
        UPDATE_MENU=
        UPDATE_BUTTONS=
        UPDATE_CARRIER=

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
                if [[ "$(active_mode)" == 'menu' ]]; then
                    ((ACTIVE_BUTTON++))
                    write_shared
                    UPDATE_BUTTONS=1
                    write_commands
                fi
                ;;

            # key down
            '[B' | j | s)
                if [[ "$(active_mode)" == 'menu' ]]; then
                    ((ACTIVE_BUTTON--))
                    write_shared
                    UPDATE_BUTTONS=1
                    write_commands
                fi
                ;;

            # key left
            '[D' | h | a)
                if [[ "$(active_button)" == 'select' && "$(active_mode)" == 'menu' ]]; then
                    ((ACTIVE_CARRIER++))
                    write_shared
                    UPDATE_CARRIER=1
                    write_commands
                fi
                ;;

            # key right
            '[C' | l | d)
                if [[ "$(active_button)" == 'select' && "$(active_mode)" == 'menu' ]]; then
                    ((ACTIVE_CARRIER--))
                    write_shared
                    UPDATE_CARRIER=1
                    write_commands
                fi
                ;;

            # key enter
            '')
                if [[ "$(active_button)" == 'start' && "$(active_mode)" == 'menu' ]]; then
                    MODE=1 # start the game
                    write_shared
                    write_commands
                fi
                ;;

            # ignore everything else
            *) continue;;
        esac

    done
}

main "$@"
