#! /usr/bin/env bash

networkpid=""

checknc() {
if ! command -v nc ./dev/null 2>&1; then
	error "nc is not installed"
	return 1
fi
}

startchat() {
local id="$1"

loadsession "$id" || return 1
if [[ "$session_type" != "host" ]]; then
	error "This is not a hosted session"
	return 1
fi

checknc || return 1

runchat "host" "" "$session_port" "$id"
}

connectchat() {
local id="$1"

if [[ ! "$id" =~ ^[a-f0-9]+$ ]]; then
	error "invalid session id"
	return 1
fi

loadsession "$id" || return 1

if  [[ "$session_type" != "connect" ]]; then
	error "this session is not a connection"
	return 1
fi

checknc || return 1

if ! checkip "$session_host"; then
	error "invalid ip"
	return 1
fi

info "connect to $session_host:$session_port"

nc "$session_host" "$session_port"
}

stopchat() {
local id="$1"

if [[ ! "$id" =~ ^[a-f0-9]+$ ]]; then
	error "invalid session id"
	return 1
fi

if kill -0 "$session_pid" 2>/dev/null; then
	kill "$session_pid" 2>/dev/null
	info "chat stopped"
else
	warn "chat is not running"
fi

updatesession "$id" "status" "stopped"
updatesession "$id" "pid" ""
}

networkinit(){
checknc || return 1
}

wrapmessage() {
local message="$1"
local alignment="$2"
local width

local indent=0
local text="$message"
local line=""

if [[ "$alignment" == "right" ]]; then
	indent=0
fi

while [[ -n "$text" ]]; do
	local word="${text%% *}"

	if [[ -z "$line" ]]; then
		line="$word"
	elif (( ${#line} + ${#word} + 1 <= width)); then
		line = "$line $word"
	else
		printline "$line" "$alignment" "$width"
		line="$word"
	fi

	if [[ "$text" == *" "* ]]; then
		text="${text#* }"
	else
		text=""
	fi
done

[[ -n "$line" ]] && printline "$line" "$alignment" "$width"
}

printline() {
local line="$1"
local alignment="$2"
local width="$3"

printf '\r\033[2K'
if [[ "$alignment" == "right" ]]; then
	printf '%*s\n' "$width" "$line"
else
	printf '%s\n' "$line"
fi
}

getwidth() {
local width
width="$(tput cols 2>/dev/null)"
printf '%s\n' "${width:-80}"
}

sendmessage() {
local message="$1"
wrapmessage "$message" "right"
}

receivemessage() {
local message="$1"
wrapmessage "$message" "left"
}

runchat() {
local type="$1" host="$2" port="$3" id="$4"
local tempdir fifo incoming
local oldstty input="" key received

tempdir="$(mktemp -d)" || return 1
fifo="$tempdir/chat"
incoming="$tempdir/incoming"

mkfifo "$fifo" "$incoming" || {
	rm -rf "$tempdir"
	return 1
}

exec 3<>"$fifo"
exec 4<>"$incoming"

info "Starting chat"
info "Use /quit to leave"
echo

case "$type" in
    host)
		case "$os" in
            macos)
                nc -l "$port" <&3 >&4 &
                ;;
            *)
                nc -l -p "$port" <&3 >&4 &
                ;;
        esac
        ;;
    connect)
        nc "$host" "$port" <&3 >&4 &
        ;;
    *)
        error "Invalid chat type."
        exec 3>&-
        exec 4>&-
        rm -rf "$tempdir"
        return 1
        ;;
esac

networkpid=$!
updatesession "$id" "status" "running"
updatesession "$id" "pid" "$networkpid"

oldstty="$(stty -g 2>/dev/null)"
if [[ -n "$oldstty" ]]; then
    stty -echo -icanon
fi

input=""
while kill -0 "$networkpid" 2>/dev/null; do
    while IFS= read -r -t 0.01 -u 4 received; do
        receivemessage "$received"
        printf '\r\033[2K> %s' "$input"
    done
	key=""
	if read -r -s -n 1 -t 0.05 key; then
		case "$key" in
			"")
				;;
			$'\n'|$'\r')
				printf '\r\033[2K'

				if [[ "$input" == "/quit" ]]; then
					break
				fi

				if [[ -n "$input" ]]; then
					sendmessage "$username: $input"
					printf '%s: %s\n' "$username" "$input" >&3
				fi

				input=""
				printf '> '
				;;
			$'\177'|$'\b')
				input="${input%?}"
				printf '\r\033[2K> %s' "$input"
				;;
			*)
				input+="$key"
				printf '%s' "$key"
				;;
		esac
	fi
done

if [[ -n "$oldstty" ]] then
	stty "$oldstty"
fi

exec 3>&-
exec 4>&-

kill "$networkpid" 2>/dev/null
wait "$networkpid" 2>/dev/null

rm -rf "$tempdir"

updatesession "$id" "status" "stopped"
updatesession "$id" "pid" ""

echo
info "Chat ended"
}
































