#! /usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
reset='\033[0m'


info() {
printf "${green}[+]${reset} %s\n" "$1"
}

warn(){
printf "${yellow}[!]${reset} %s\n" "$1"
}

error() {
printf "${red}[-]${reset} %s\n" "$1">&2
}

clearpage() {
echo
read -r -p "press enter to continue" _
}


chackport() {
local port="$1"

[[ "$port" =~ ^[0-9]+$ ]] || return 1
(( port >= 1 && port <= 65535))

}

checkip() {
local ip="$1"
local a b c d
[[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
IFS='.' read -r a b c d <<< "$ip"
for octet in "$a" "$b" "$c" "$d"; do
	(( 10#$octet <= 255 )) || return 1
done

return 0
}

findip(){
local ip=""
case "$os" in
	linux)
		if command -v ip > /dev/null 2>&1; then
			ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')"
		fi
	;;
	macos)
		local interface

		interface="$(route -n get default 2>/dev/null | awk '/interface: / {print $2}')"
		if [[ -n "$interface" ]]; then
			ip="$(ipconfig getifaddr "$interface" 2>/dev/null)"
		fi
		;;
	windows)
		if command -v ipconfig >/dev/null 2>&1; then
			ip="$(ipconfig | awk '/IPV4 Address/ {print $NF; exit}')"
		fi
		;;
esac

if checkip "$ip"; then
	printf '%s\n' "$ip"
	return 0
fi

return 1

}


getdate() {
date '+%Y-%m-%d_%H-%M_%S'
}

sesid() {
if [[ -r /dev/urandom ]]; then
	od -An -N4 -tx1 /dev/urandom | tr -d ' \n'
else
	printf '%s' "$RANDOM$RANDOM"
fi
}
