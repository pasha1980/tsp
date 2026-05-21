#!/usr/bin/env bash


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

active_mode() {
    local mode=$(get_shared | split '|' 0)
    case "$((mode % 2))" in
        0) echo -n 'menu';;
        1 | -1) echo -n 'gameplay';;
    esac
}

active_button() {
    local active_btn=$(get_shared | split '|' 1)
    case "$((active_btn % 2))" in
        0) echo -n 'start';;
        1 | -1) echo -n 'select';;
    esac
}

active_carrier() {
    local length=${#CARRIERS[@]}
    local active_carr=$(get_shared | split '|' 2)
    active_carr=${active_carr#-}
    local index=$((active_carr % length))
    echo "${CARRIERS[$index]}"
}

# shared memory
write_shared() {
    echo "${MODE:-0}|${ACTIVE_BUTTON:-0}|${ACTIVE_CARRIER:-0}|${COLS:-0}|${LINES:-0}" > "$SHM"
}

get_shared() {
    local res=$(cat "$SHM" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo "$res"
    fi
}

write_commands() {
    echo "${UPDATE_MENU:-0}|${UPDATE_BUTTONS:-0}|${UPDATE_CARRIER:-0}" > $CPIPE &
}

read_commands() {
    cat $CPIPE
}

# calculations
orbit_calc() {
    while :; do
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
    [[ $(active_button) == 'start' ]] && start_esc="${ESC}[48;5;255m${ESC}[38;5;243m${ESC}[1m" \
    || select_esc="${ESC}[48;5;255m${ESC}[38;5;243m${ESC}[1m"

    tput cup "$start_button_line" "$start_button_col"
    printf "%s%s${ESC}[0m" "$start_esc" "$START_BUTTON"

    tput cup "$select_button_line" "$select_button_col"
    printf "%s%s${ESC}[0m" "$select_esc" "$SELECT_BUTTON"
}

render_carriers() {
   local start_line=$1
   local start_indent=$2
   local i=0

   while IFS= read -r line; do
       tput cup "$((start_line + i))" "$start_indent"
       printf "$(repeat 17 ' ')"
       tput cup "$((start_line + i))" "$start_indent"
       printf "$line"
       ((i++))
   done <<< "$(active_carrier)"
}

render_menu() {
    local comm=$(read_commands)
    local u_menu=$(echo "$comm"| split '|' 0)
    local u_buttons=$(echo "$comm"| split '|' 1)
    local u_carriers=$(echo "$comm"| split '|' 2)

    local shared=$(get_shared)
    if [[ -z $shared ]]; then
        return 0
    fi

    local theCols=$(echo "$shared" | split '|' 3)
    local theLines=$(echo "$shared" | split '|' 4)

    if (( $u_menu )); then
        echo u_menu >> debug5
        clear
        local logo_line=$((theLines / 6))
        local logo_indent=$(calc_d "$theCols / 3.77")
        tput cup "$logo_line" 0
        local l=$LOGO
        l=${l//<l>/$(repeat $logo_indent ' ')}
        printf "$l"

        tput cup $(calc_d "$theLines / 1.1") 0
        local f=$SURFACE_BLOCK
        f=${f//<b1>/$(repeat $theCols '_')}
        f=${f//<b2>/$(repeat $theCols '/')}

        printf "$f"
    fi

    if (( $u_buttons )); then
        render_buttons $(calc_d "$theLines / 2.6") $(calc_d "$theCols / 2.35")
    fi

    if (( $u_carriers )); then
        local carrier_indent=$(calc_d "$theCols / 2.2")
        local carrier_line=$(calc_d "$theLines / 1.5")
        render_carriers "$carrier_line" "$carrier_indent"
    fi

    tput cup 0 0
}

render_gameplay() {
    local shared=$(get_shared)
    if [[ -z $shared ]]; then
        return 0
    fi

    local cols=$(echo "$shared" | split '|' 3)
    local lines=$(echo "$shared" | split '|' 4)

    # show surface if we need
    local surface_height=$(calc_d "$lines - ($lines / 1.1)")
    if (( (G_h + (lines / 3)) < surface_height )); then
        tput cup "$(($lines - $surface_height))" 0
        local f=$SURFACE_BLOCK
        f=${f//<b1>/$(repeat $cols '_')}
        f=${f//<b2>/$(repeat $cols '/')}
        printf "$f"
    fi
}

render() {
    while :; do
        case "$(active_mode)" in
            menu) render_menu;;
            gameplay) render_gameplay;;
        esac
    done
}

main() {
    # ensure we are called interactively
    if [[ ! -t 1 ]]; then
        echo '[error] stdout must be a terminal. Run game in interactive mode'
        exit 1
    fi
    
    tput cup 0 0 2>/dev/null

    # configure terminal for drawing
    trap cleanup exit
    printf "${ESC}[?1049h"
    printf "${ESC}[?25l"

    local escape_char=$'\u1b'

    write_shared
    render &
    RENDERING_PID=$!

    write_commands

    while :; do
        UPDATE_MENU=
        UPDATE_BUTTONS=
        UPDATE_CARRIER=

        local theCols=$(cols)
        if (( theCols != COLS )); then
            UPDATE_MENU=1
            COLS=$theCols
        fi

        local theLines=$(lines)
        if (( theLines != LINES )); then
            UPDATE_MENU=1
            LINES=$theLines
        fi

        local input=
        read -rsn1 input < /dev/tty 2>/dev/null
        if [[ $input == "$escape_char" ]]; then
            read -rsn2 input < /dev/tty 2>/dev/null
        fi

        case "$input" in
            # key up
            'A' | '[A' | k | w)
                if [[ "$(active_mode)" == 'menu' ]]; then
                    ((ACTIVE_BUTTON++))
                    write_shared
                    UPDATE_BUTTONS=1
                    write_commands
                fi
                ;;

            # key down
            'B' | '[B' | j | s)
                if [[ "$(active_mode)" == 'menu' ]]; then
                    ((ACTIVE_BUTTON--))
                    write_shared
                    UPDATE_BUTTONS=1
                    write_commands
                fi
                ;;

            # key left
            'D' | '[D' | h | a)
                if [[ "$(active_button)" == 'select' && "$(active_mode)" == 'menu' ]]; then
                    ((ACTIVE_CARRIER++))
                    write_shared
                    UPDATE_CARRIER=1
                    write_commands
                fi
                ;;

            # key right
            'C' | '[C' | l | d)
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

# reference: https://github.com/bahamas10/bash-tput
tput() {
	local opt OPTIND OPTARG
	while getopts 'ST:V' opt; do
		case "$opt" in
			S) command tput "$@"; return $?;;
			T) true;;
			V) echo "$VERSION"; return 0;;
		esac
	done
	shift "$((OPTIND - 1))"

	local ESC=$'\x1b'
	case "$1" in
		bel) echo -n $'\x7';;
		sgr0 | me) echo -n "$ESC[0m";;
		bold) echo -n "$ESC[1m";;
		dim) echo -n "$ESC[2m";;
		rev) echo -n "$ESC[7m";;
		blink) echo -n "$ESC[5m";;
		setaf | AF) echo -n "$ESC[38;5;$2m";;
		setab | AB) echo -n "$ESC[48;5;$2m";;
		sc) echo -n "${ESC}7";;
		rc) echo -n "${ESC}8";;
		cnorm) echo -n "$ESC[?25h";;
		civis) echo -n "$ESC[?25l";;
		smcup) echo -n "$ESC[?1049h";;
		rmcup) echo -n "$ESC[?1049l";;
		clear) echo -n "$ESC[H$ESC[2J";;
		home) echo -n "$ESC[H";;
		cuu) echo -n "$ESC[$2A";;
		cud) echo -n "$ESC[$2B";;
		cuf) echo -n "$ESC[$2C";;
		cub) echo -n "$ESC[$2D";;
		cup)
			local row=$(($2 + 1))
			local col=$(($3 + 1))
			echo -n "$ESC[$row;${col}H";;
		*) command tput "$@"; return $?;;
	esac
}

# reference: https://github.com/dylanaraps/pure-bash-bible?tab=readme-ov-file#split-a-string-on-a-delimiter
split() {
  data=$(</dev/stdin)
  IFS=$'\n' read -d "" -ra arr <<< "${data//$1/$'\n'}"
  printf '%s\n' "${arr[$2]}"
}

lines() {
  stty size | split ' ' 0
}

cols() {
  stty size | split ' ' 1
}

# terminal constants
COLS=$(cols)
LINS=$(lines)
ESC=$'\x1b'
SHMID=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c 64; echo)
SHM=$([[ "$(uname -s)" == 'Darwin' ]] && echo "/tmp/$SHMID" || echo "/dev/shm/$SHMID")
CPIPE="/tmp/$SHMID.fifo"
if [[ ! -p $CPIPE ]]; then
    mkfifo "$CPIPE"
fi

# frames
LOGO="
<l>  _____ _______   __  ___                     ___
<l> |_   _|_   _\ \ / / / __|_ __  __ _ __ ___  | _ \_ _ ___  __ _ _ _ __ _ _ __
<l>   | |   | |  \ V /  \__ \ \'_ \/ _\` / _/ -_) |  _/ \'_/ _ \/ _\` | \'_/ _\` | \'  \\
<l>   |_|   |_|   |_|   |___/ .__/\__,_\__\___| |_| |_| \___/\__, |_| \__,_|_|_|_|
<l>                         |_|                              |___/
"

SURFACE_BLOCK="
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


main "$@"
