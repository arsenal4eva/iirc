#! /usr/bin/env bash


mainmenu() {
while true; do
	clear

	printf "${cyan}"
	printf 'IIRC\n'
	printf '    by arsenal4eva\n\n'
	printf "${reset}"

	printf '[1] Host chat\n'
	printf '[2] Connect to chat\n'
	printf '[3] Saved sessions\n'
	printf '[4] Settings\n'
	printf '[5] Exit\n\n'

	read -r -p "  > " choice

	case "$choice" in
		1) hostmenu ;;
		2) connectmenu ;;
		3) sessionmenu ;;
		4) settingsmenu ;;
		5)
			echo "Bye bye"
			exit 0
			;;
		*)
			warn "invalid option"
			clearpage
			;;

	esac
done
}

hostmenu(){
clear

local name port ip id
ip="$(findip)"
echo "Host a chat"
echo "-----------"
printf 'Your ip: %s\n\n' "${ip:-Unknown}"

read -r -p "Session name: " name
[[ -n "$name" ]] || {
	warn "session name cannot be empty"
	clearpage
	return
}

read -r -p "Port [$defaultport]: " port
port="${port:-$defaultport}"

if ! chackport "$port"; then
	error "invalid port"
	clearpage
	return
fi

id="$(createsession "$name" "host" "0.0.0.0" "$port")" || {
	clearpage
	return
}

echo 
info "Share this address with the other person:"
printf '%s:%s\n' "${ip:-your-ip}" "$port"
echo

read -r -p "press enter to start hosting chat"

startchat "$id"
clearpage
}

connectmenu() {
clear
local name host port id
echo "Connect to a chat"
echo "-----------------"

read -r -p "Session name: " name
[[ -m "$name" ]] || {
	warn "session name cannot be empty"
	clearpage
	return
}

read -r -p "Host ip addr: " host
if ! checkip "$host"; then
	error "Invalid ip addr"
	clearpage
	return
fi

read -r -p "Port [$defaultport]: " port
port="${port:-$defaultport}"

if ! chackport "$port"; then
	error "invalid port"
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
while true; do
	clear

	echo "Saved sessions"
	echo "--------------"

	listsessions

	printf '[1] Connect to a session\n'
	printf '[2] Start hosted session\n'
	printf '[3] Delete session\n'
	printf '[4] Back\n\n'

	read -r -p "  > " choice

	local id

	case "$choice" in
		1)
			read -r -p "Session id: " id
			connectchat "$id"
			clearpage
			;;
		2)
			read -r -p "Session id: " id
			startchat "$id"
			clearpage
			;;
		3)
			read -r -p "Session id: " id
			deletesession "$id"
			clearpage
			;;
		4)
			return
			;;
		*)
			warn "invalid option"
			clearpage
			;;
	esac
done
}
settingsmenu() {
while true; do
	clear
	echo "Settings"
	echo "--------"
	printf 'Username: %s\n' "$username"
	printf 'Default port: %s\n' "$defaultport"
	printf 'Timestamps: %s\n' "$timestamps"
	printf 'Save logs: %s\n' "$save_logs"
	printf 'Auto reconnect: %s\n' "$auto_reconnect"

	printf '[1] Change username\n'
	printf '[2] Change default port\n'
	printf '[3] Toggle timestamps\n'
	printf '[4] Toggle log saving\n'
	printf '[5] Toggle auto reconnect\n'
	printf '[6] Back \n\n'

	read -r -p "  > " choice

	case "$choice" in
		1)
			read -r -p "New username: " username
			[[ -n "$username" ]] && saveconfig
			;;
		2)
			local port
			read -r -p "New default port: " port
			if chackport "$port"; then
				defaultport="$port"
				saveconfig
			else
				error "invalid port"
			fi
			;;
		3)
			if [[ "$timestamps" == "true" ]]; then
				timestamps="false"
			else
				timestamps=""true
			fi
			saveconfig
			;;
		4)
			if [[ "$save_logs" == "true" ]]; then
				save_logs="false"
			else
				save_logs="true"
			fi
			saveconfig
			;;
		5)
			if [[ "$auto_reconnect" == "true" ]]; then
				auto_reconnect="false"
			else
				auto_reconnect="true"
			fi
			saveconfig
			;;
		6)
			return
			;;
		*)
			warn "invalid choice"
			;;
	esac
	clearpage
done
}


iirc_main_menu() {
mainmenu
}



























































