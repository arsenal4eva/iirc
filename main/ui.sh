#! /usr/bin/env bash

menu_header() {
	clear_screen
	printf '%sIIRC%s\n' "$cyan" "$reset"
	printf '    by arsenal4eva\n\n'
}

mainmenu() {
	local choice

	while true; do
		menu_header

		printf '[1] Host chat\n'
		printf '[2] Connect to chat\n'
		printf '[3] Saved sessions\n'
		printf '[4] Settings\n'
		printf '[5] Exit\n\n'

		read -r -p "  > " choice || { echo; exit 0; }

		case "$choice" in
			1) hostmenu ;;
			2) connectmenu ;;
			3) sessionmenu ;;
			4) settingsmenu ;;
			5)
				echo "Bye bye"
				exit 0
				;;
			*) warn "invalid option" ;;
		esac
	done
}

pickid() {
	local id

	read -r -p "Session id (b to go back): " id || return 1
	id="$(trim "$id")"

	[[ -z "$id" || "$id" == "b" ]] && return 1

	if ! validid "$id"; then
		warn "invalid session id"
		return 1
	fi

	if ! sessionexists "$id"; then
		warn "session not found"
		return 1
	fi

	printf '%s\n' "$id"
}

hostmenu() {
	clear_screen

	local name port ip id
	ip="$(findip)"
	echo "Host a chat"
	echo "-----------"
	printf 'Your ip: %s\n\n' "${ip:-Unknown}"

	read -r -p "Session name: " name || return
	if [[ -z "$(trim "$name")" ]]; then
		warn "session name cannot be empty"
		clearpage
		return
	fi

	read -r -p "Port [$defaultport]: " port || return
	port="$(trim "${port:-$defaultport}")"

	if ! checkport "$port"; then
		warn "invalid port"
		clearpage
		return
	fi

	if ! portfree "$port"; then
		local suggestion
		warn "port $port is already in use"
		suggestion="$(findfreeport "$port" 2>/dev/null || true)"
		if [[ -n "$suggestion" ]] && confirm "use port $suggestion instead?"; then
			port="$suggestion"
		else
			clearpage
			return
		fi
	fi

	id="$(createsession "$name" "host" "0.0.0.0" "$port")" || {
		clearpage
		return
	}

	echo
	info "Share this address with the other person:"
	printf '%s:%s\n' "${ip:-your-ip}" "$port"
	echo
	printf 'Session id: %s\n\n' "$id"

	read -r -p "press enter to start hosting chat" _

	startchat "$id"
	clearpage
}

connectmenu() {
	clear_screen

	local name host port id
	echo "Connect to a chat"
	echo "-----------------"

	read -r -p "Session name: " name || return
	if [[ -z "$(trim "$name")" ]]; then
		warn "session name cannot be empty"
		clearpage
		return
	fi

	read -r -p "Host ip or name: " host || return
	host="$(trim "$host")"
	if ! checkhost "$host"; then
		warn "invalid host"
		clearpage
		return
	fi

	read -r -p "Port [$defaultport]: " port || return
	port="$(trim "${port:-$defaultport}")"

	if ! checkport "$port"; then
		warn "invalid port"
		clearpage
		return
	fi

	id="$(createsession "$name" "connect" "$host" "$port")" || {
		clearpage
		return
	}

	connectchat "$id"
	clearpage
}

sessionmenu() {
	local choice id

	while true; do
		menu_header
		echo "Saved sessions"
		echo "--------------"
		echo

		listsessions

		printf '[1] Connect to a session\n'
		printf '[2] Start hosted session\n'
		printf '[3] Stop a running session\n'
		printf '[4] Delete session\n'
		printf '[5] Back\n\n'

		read -r -p "  > " choice || return

		case "$choice" in
			1)
				id="$(pickid)" || { warn "no session selected"; continue; }
				connectchat "$id"
				clearpage
				;;
			2)
				id="$(pickid)" || { warn "no session selected"; continue; }
				startchat "$id"
				clearpage
				;;
			3)
				id="$(pickid)" || { warn "no session selected"; continue; }
				stopchat "$id"
				clearpage
				;;
			4)
				id="$(pickid)" || { warn "no session selected"; continue; }
				if confirm "delete session $id?"; then
					deletesession "$id"
				fi
				clearpage
				;;
			5) return ;;
			*) warn "invalid option" ;;
		esac
	done
}

settingsmenu() {
	local choice value

	while true; do
		menu_header
		echo "Settings"
		echo "--------"
		printf 'Username:       %s\n' "$username"
		printf 'Default port:   %s\n' "$defaultport"
		printf 'Timestamps:     %s\n' "$timestamps"
		printf 'Save logs:      %s\n' "$save_logs"
		printf 'Auto reconnect: %s\n\n' "$auto_reconnect"

		printf '[1] Change username\n'
		printf '[2] Change default port\n'
		printf '[3] Toggle timestamps\n'
		printf '[4] Toggle log saving\n'
		printf '[5] Toggle auto reconnect\n'
		printf '[6] Back\n\n'

		read -r -p "  > " choice || return

		case "$choice" in
			1)
				read -r -p "New username: " value || continue
				if setusername "$value"; then
					saveconfig
				else
					warn "invalid username"
				fi
				;;
			2)
				read -r -p "New default port: " value || continue
				value="$(trim "$value")"
				if checkport "$value"; then
					defaultport="$value"
					saveconfig
				else
					warn "invalid port"
				fi
				;;
			3)
				toggle_bool timestamps
				saveconfig
				;;
			4)
				toggle_bool save_logs
				saveconfig
				;;
			5)
				toggle_bool auto_reconnect
				saveconfig
				;;
			6) return ;;
			*) warn "invalid choice" ;;
		esac
	done
}

toggle_bool() {
	local var="$1"

	if [[ "${!var}" == "true" ]]; then
		printf -v "$var" '%s' "false"
	else
		printf -v "$var" '%s' "true"
	fi
}

iirc_main_menu() {
	mainmenu
}
