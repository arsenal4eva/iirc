#! /usr/bin/env bash

NC_BIN=""
NC_LISTEN_ARGS=()
CHAT_POLL="0.1"
chat_tmp=""
chat_pid=""
chat_oldstty=""
chat_input=""
chat_width=80
chat_logfile=""
chat_type=""
chat_tty=false
chat_quit=0
chat_unexpected=0
chat_err=""
CHAT_PRINT_COLOR=""


checknc() {
	local candidate

	for candidate in nc ncat netcat; do
		if have "$candidate"; then
			NC_BIN="$candidate"
			return 0
		fi
	done

	NC_BIN=""
	error "netcat (nc) is not installed"
	return 1
}

networkinit() {
	if (( BASH_VERSINFO[0] < 4 )); then
		CHAT_POLL="1"
	else
		CHAT_POLL="0.1"
	fi

	if ! checknc; then
		warn "chat is unavailable until netcat is installed"
		return 1
	fi

	NC_LISTEN_ARGS=(-l -p)
	if [[ "$NC_BIN" == "ncat" || "$os" == "macos" ]]; then
		NC_LISTEN_ARGS=(-l)
	fi

	if [[ -n "${IIRC_NC_LISTEN_ARGS:-}" ]]; then
		read -r -a NC_LISTEN_ARGS <<< "$IIRC_NC_LISTEN_ARGS"
	fi

	return 0
}


getwidth() {
	local width=""

	if [[ -t 1 ]]; then
		width="$(tput cols 2>/dev/null || true)"
	fi

	if [[ ! "$width" =~ ^[0-9]+$ ]]; then
		width="${COLUMNS:-80}"
	fi
	[[ "$width" =~ ^[0-9]+$ ]] || width=80
	(( width < 20 )) && width=80

	printf '%s\n' "$width"
}

printline() {
	local line="$1"
	local alignment="$2"
	local width="$3"
	local pad

	if [[ "$alignment" == "right" ]]; then
		pad=$(( width - ${#line} ))
		(( pad < 0 )) && pad=0
		printf '%*s' "$pad" ""
	fi

	if [[ -n "$CHAT_PRINT_COLOR" ]]; then
		printf '%s%s%s\n' "$CHAT_PRINT_COLOR" "$line" "$reset"
	else
		printf '%s\n' "$line"
	fi
}

wrapmessage() {
	local text="$1"
	local alignment="${2:-left}"
	local width="${3:-80}"
	local line="" word=""

	[[ "$width" =~ ^[0-9]+$ ]] || width=80
	(( width < 10 )) && width=10

	text="${text//$'\t'/    }"

	while [[ -n "$text" ]]; do
		text="${text#"${text%%[! ]*}"}"

		if [[ "$text" == *" "* ]]; then
			word="${text%% *}"
			text="${text#* }"
		else
			word="$text"
			text=""
		fi

		[[ -z "$word" ]] && continue

		while (( ${#word} > width )); do
			if [[ -n "$line" ]]; then
				printline "$line" "$alignment" "$width"
				line=""
			fi
			printline "${word:0:width}" "$alignment" "$width"
			word="${word:width}"
		done

		[[ -z "$word" ]] && continue

		if [[ -z "$line" ]]; then
			line="$word"
		elif (( ${#line} + 1 + ${#word} <= width )); then
			line+=" $word"
		else
			printline "$line" "$alignment" "$width"
			line="$word"
		fi
	done

	[[ -n "$line" ]] && printline "$line" "$alignment" "$width"
	return 0
}

sendmessage() {
	wrapmessage "$1" "right" "${2:-$chat_width}"
}

receivemessage() {
	wrapmessage "$1" "left" "${2:-$chat_width}"
}


chat_log() {
	local direction="$1"
	local text="$2"

	[[ "${save_logs:-false}" == "true" ]] || return 0
	[[ -n "$chat_logfile" ]] || return 0

	printf '[%s] %-8s %s\n' "$(nowstamp)" "$direction" "$text" >> "$chat_logfile" 2>/dev/null || true
}

chat_render_prompt() {
	[[ "$chat_tty" == "true" ]] || return 0
	printf '\r\033[2K%s> %s%s' "$cyan" "$chat_input" "$reset"
}

chat_print() {
	local text="$1"
	local alignment="${2:-left}"
	local color="${3:-}"

	if [[ "${timestamps:-false}" == "true" ]]; then
		text="[$(shorttime)] $text"
	fi

	[[ "$chat_tty" == "true" ]] && printf '\r\033[2K'

	CHAT_PRINT_COLOR="$color"
	wrapmessage "$text" "$alignment" "$chat_width"
	CHAT_PRINT_COLOR=""

	chat_render_prompt
}

chat_incoming() {
	local msg="${1%$'\r'}"
	local color

	[[ -n "$msg" ]] || return 0

	case "$msg" in
		\**) color="$yellow" ;;
		*) color="$green" ;;
	esac

	chat_print "$msg" "left" "$color"
	chat_log "incoming" "$msg"
}

chat_outgoing() {
	chat_print "$1" "right" "$cyan"
	chat_log "outgoing" "$1"
}

chat_send() {
	printf '%s\n' "$1" >&3 2>/dev/null
}

CHAT_PING_INTERVAL=2
chat_last_ping=0

chat_keepalive() {
	(( SECONDS - chat_last_ping >= CHAT_PING_INTERVAL )) || return 0
	chat_last_ping=$SECONDS
	printf '\n' >&3 2>/dev/null || return 1
	return 0
}


chat_help() {
	chat_print "/quit              leave the chat" "left" "$yellow"
	chat_print "/nick <name>       change your username" "left" "$yellow"
	chat_print "/me <action>       send an action" "left" "$yellow"
	chat_print "/clear             clear the screen" "left" "$yellow"
	chat_print "/help              show this help" "left" "$yellow"
}

chat_command() {
	local line="${1%$'\r'}"

	case "$line" in
		/quit|/exit|/q)
			chat_quit=1
			return 0
			;;
		/help|/\?)
			chat_help
			return 0
			;;
		/clear|/cls)
			clear_screen
			chat_render_prompt
			return 0
			;;
		/nick)
			warn "usage: /nick <name>"
			return 0
			;;
		/nick\ *)
			local newnick oldname="$username"
			newnick="$(trim "${line#/nick }")"
			if ! setusername "$newnick"; then
				warn "invalid username"
				return 0
			fi
			saveconfig >/dev/null 2>&1 || true
			chat_send "* $oldname is now known as $username"
			chat_print "* you are now known as $username" "left" "$yellow"
			chat_log "system" "nick change: $oldname -> $username"
			return 0
			;;
		/me)
			warn "usage: /me <action>"
			return 0
			;;
		/me\ *)
			local action="${line#/me }"
			chat_send "* $username $action"
			chat_outgoing "* $username $action"
			return 0
			;;
		/*)
			warn "unknown command: $line (try /help)"
			return 0
			;;
	esac

	[[ -n "$line" ]] || return 0

	if ! chat_send "$username: $line"; then
		warn "could not send message: connection closed"
		chat_quit=1
		return 1
	fi

	chat_outgoing "$username: $line"
	return 0
}


chat_cleanup() {
	local pid="$chat_pid"

	chat_pid=""

	{ exec 3>&-; } 2>/dev/null || true

	if [[ -n "$pid" ]]; then
		sleep 0.15
		kill "$pid" 2>/dev/null || true
		wait "$pid" 2>/dev/null || true
	fi

	{ exec 4>&-; } 2>/dev/null || true

	if [[ -n "$chat_oldstty" ]]; then
		stty "$chat_oldstty" 2>/dev/null || stty sane 2>/dev/null || true
		chat_oldstty=""
	fi

	if [[ -n "$chat_tmp" ]]; then
		rm -rf "$chat_tmp"
		chat_tmp=""
	fi

	return 0
}

chat_spawn() {
	local type="$1"
	local host="$2"
	local port="$3"
	local errfile="$chat_tmp/nc.err"
	local attempt=0 max=1 delay=1 msg

	[[ "$type" == "connect" ]] && max="${IIRC_CONNECT_RETRIES:-5}"

	while :; do
		attempt=$(( attempt + 1 ))
		: > "$errfile"

		if [[ "$type" == "host" ]]; then
			"$NC_BIN" "${NC_LISTEN_ARGS[@]}" "$port" <&3 >&4 2>"$errfile" &
		else
			"$NC_BIN" "$host" "$port" <&3 >&4 2>"$errfile" &
		fi
		chat_pid=$!

		local i=0
		while (( i < 3 )); do
			sleep 0.1
			kill -0 "$chat_pid" 2>/dev/null || break
			i=$(( i + 1 ))
		done

		kill -0 "$chat_pid" 2>/dev/null && return 0

		msg="$(tr -d '\r' < "$errfile" 2>/dev/null | head -n 2 | tr '\n' ' ')"
		msg="$(trim "$msg")"
		if [[ -z "$msg" ]]; then
			if [[ "$type" == "connect" ]]; then
				msg="connection failed"
			else
				msg="could not listen on port $port"
			fi
		fi

		if (( attempt >= max )); then
			if [[ "$type" == "connect" ]]; then
				error "could not connect to $host:$port ($msg)"
			else
				error "could not start chat ($msg)"
			fi
			return 1
		fi

		warn "$msg, retrying ($attempt/$max)"
		sleep "$delay"
	done
}

chat_drain() {
	local msg

	while IFS= read -r -t "$CHAT_POLL" -u 4 msg; do
		chat_incoming "$msg"
	done
}

chat_peer_check() {
	kill -0 "$chat_pid" 2>/dev/null && return 0

	chat_unexpected=1
	chat_err="$(tr -d '\r' < "$chat_tmp/nc.err" 2>/dev/null | head -n 1)"
	[[ -n "$chat_err" ]] || chat_err="connection closed"
	return 1
}

chat_loop_tty() {
	local key rc k

	while (( chat_quit == 0 )); do
		chat_keepalive
		chat_drain
		chat_peer_check || break

		key=""
		IFS= read -r -s -n 1 -t "$CHAT_POLL" key
		rc=$?

		(( rc > 128 )) && continue
		if (( rc != 0 )); then
			chat_unexpected=1
			chat_err="input closed"
			break
		fi

		case "$key" in
			""|$'\n'|$'\r')
				local line="$chat_input"
				chat_input=""
				chat_render_prompt
				chat_command "$line"
				;;
			$'\177'|$'\b')
				if [[ -n "$chat_input" ]]; then
					chat_input="${chat_input%?}"
					chat_render_prompt
				fi
				;;
			$'\025') 
				chat_input=""
				chat_render_prompt
				;;
			$'\003'|$'\004') 
				chat_quit=1
				;;
			$'\033') 
				if (( BASH_VERSINFO[0] >= 4 )); then
					for k in 1 2; do
						IFS= read -r -s -n 1 -t 0.01 k || break
					done
				else
					IFS= read -r -s -n 1 -t 1 k || true
				fi
				;;
			$'\t')
				chat_input+=" "
				printf ' '
				;;
			*)
				chat_input+="$key"
				printf '%s' "$key"
				;;
		esac
	done
}

chat_loop_pipe() {
	local line rc

	while (( chat_quit == 0 )); do
		chat_keepalive
		chat_drain
		chat_peer_check || break

		line=""
		IFS= read -r -t "$CHAT_POLL" line
		rc=$?

		(( rc > 128 )) && continue
		if (( rc != 0 )); then
			chat_quit=1
			break
		fi

		chat_command "$line"
	done
}


startchat() {
	local id="$1"

	loadsession "$id" || return 1

	if [[ "$session_type" != "host" ]]; then
		error "this is not a hosted session"
		return 1
	fi

	if [[ -z "$session_port" ]]; then
		error "session has an invalid port"
		return 1
	fi

	checknc || return 1

	if ! portfree "$session_port"; then
		error "port $session_port is already in use"
		return 1
	fi

	runchat "host" "" "$session_port" "$id"
}

connectchat() {
	local id="$1"

	if ! validid "$id"; then
		error "invalid session id: $id"
		return 1
	fi

	loadsession "$id" || return 1

	if [[ "$session_type" != "connect" ]]; then
		error "this session is not a connection"
		return 1
	fi

	if ! checkhost "$session_host"; then
		error "invalid host: $session_host"
		return 1
	fi

	if [[ -z "$session_port" ]]; then
		error "session has an invalid port"
		return 1
	fi

	checknc || return 1

	info "connecting to $session_host:$session_port"

	runchat "connect" "$session_host" "$session_port" "$id"
}

stopchat() {
	local id="$1"

	loadsession "$id" || return 1

	if [[ -n "$session_pid" ]] && kill -0 "$session_pid" 2>/dev/null; then
		kill "$session_pid" 2>/dev/null || true
		info "chat stopped"
	else
		warn "chat is not running"
	fi

	updatesession "$id" "status" "stopped" 2>/dev/null || true
	updatesession "$id" "pid" "" 2>/dev/null || true
}


chat_run_once() {
	local type="$1"
	local host="$2"
	local port="$3"
	local id="$4"

	chat_input=""
	chat_quit=0
	chat_unexpected=0
	chat_err=""
	chat_last_ping=0

	chat_tmp="$(mktemp -d "${TMPDIR:-/tmp}/iirc.XXXXXX" 2>/dev/null)" || {
		error "could not create temporary directory"
		return 1
	}

	if ! mkfifo "$chat_tmp/to" "$chat_tmp/from"; then
		chat_cleanup
		error "could not create communication pipes"
		return 1
	fi

	if ! { exec 3<>"$chat_tmp/to"; } 2>/dev/null || ! { exec 4<>"$chat_tmp/from"; } 2>/dev/null; then
		chat_cleanup
		error "could not open communication pipes"
		return 1
	fi

	trap 'chat_cleanup' EXIT
	trap 'chat_quit=1' INT TERM
	trap 'chat_width="$(getwidth)"' WINCH

	if [[ "$chat_tty" == "true" ]]; then
		chat_oldstty="$(stty -g 2>/dev/null)" || chat_oldstty=""
		stty -echo -icanon -isig min 1 time 0 2>/dev/null ||
			stty -echo -icanon 2>/dev/null || true
	fi

	chat_log "system" "--- chat started ($type) ---"

	if ! chat_spawn "$type" "$host" "$port"; then
		chat_log "system" "--- could not start chat ---"
		chat_cleanup
		trap - EXIT INT TERM WINCH
		return 1
	fi

	updatesession "$id" "status" "running" 2>/dev/null || true
	updatesession "$id" "pid" "$chat_pid" 2>/dev/null || true

	if [[ "$chat_tty" == "true" ]]; then
		chat_render_prompt
		chat_loop_tty
	else
		chat_loop_pipe
	fi

	chat_log "system" "--- chat ended ---"
	chat_cleanup
	trap - EXIT INT TERM WINCH

	return 0
}

runchat() {
	local type="$1"
	local host="$2"
	local port="$3"
	local id="$4"
	local attempt=0 max=1 run_rc=0

	chat_type="$type"
	chat_tty="false"
	[[ -t 0 && -t 1 ]] && chat_tty="true"
	chat_width="$(getwidth)"

	if [[ -z "${session_logfile:-}" || "$session_logfile" != "$logs"/* ]]; then
		session_logfile="$logs/$id.log"
	fi
	chat_logfile="$session_logfile"
	mkdir -p "$logs" 2>/dev/null || true

	if [[ "$type" == "connect" && "${auto_reconnect:-false}" == "true" ]]; then
		max=3
	fi

	info "Starting chat"
	info "Type /help for commands, /quit to leave"
	echo

	while :; do
		attempt=$(( attempt + 1 ))

		if ! chat_run_once "$type" "$host" "$port" "$id"; then
			run_rc=1
			break
		fi

		if (( chat_unexpected == 1 )) && (( attempt < max )); then
			warn "connection lost (${chat_err:-unknown reason})"
			warn "reconnecting ($attempt/$max)..."
			sleep 1
			continue
		fi

		break
	done

	if (( run_rc == 0 )); then
		if (( chat_unexpected == 1 )) && [[ "$chat_quit" -eq 0 ]]; then
			warn "chat ended: ${chat_err:-peer disconnected}"
		elif [[ "$chat_quit" -eq 1 ]]; then
			info "Chat ended"
		fi
	fi

	updatesession "$id" "status" "stopped" 2>/dev/null || true
	updatesession "$id" "pid" "" 2>/dev/null || true

	echo
	return "$run_rc"
}
