#! /usr/bin/env bash

if [[ -z "${NO_COLOR:-}" && ( -t 1 || -t 2 ) ]]; then
	red=$'\033[0;31m'
	green=$'\033[0;32m'
	yellow=$'\033[1;33m'
	blue=$'\033[0;34m'
	cyan=$'\033[0;36m'
	reset=$'\033[0m'
else
	red=''
	green=''
	yellow=''
	blue=''
	cyan=''
	reset=''
fi


info() {
	printf '%s[+]%s %s\n' "$green" "$reset" "$*"
}

warn() {
	printf '%s[!]%s %s\n' "$yellow" "$reset" "$*" >&2
}

error() {
	printf '%s[-]%s %s\n' "$red" "$reset" "$*" >&2
	return 1
}

have() {
	command -v "$1" >/dev/null 2>&1
}


clear_screen() {
	if [[ -t 1 && -n "${TERM:-}" && "${TERM}" != "dumb" ]]; then
		printf '\033[H\033[2J\033[3J'
	else
		printf '\n'
	fi
}

clearpage() {
	[[ -t 0 ]] || return 0
	printf '\n'
	read -r -p "press enter to continue" _ || true
}


trim() {
	local s="$1"
	s="${s#"${s%%[![:space:]]*}"}"
	s="${s%"${s##*[![:space:]]}"}"
	printf '%s' "$s"
}

sanitize_text() {
	printf '%s' "$1" | tr -d '\r\n' | tr '"' "'"
}


chackport() {
	checkport "$@"
}

checkport() {
	local port="$1"

	[[ "$port" =~ ^[0-9]{1,5}$ ]] || return 1
	(( 10#$port >= 1 && 10#$port <= 65535 ))
}

checkip() {
	local ip="$1"
	local octet

	[[ "$ip" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1

	for octet in "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"; do
		(( 10#$octet <= 255 )) || return 1
	done

	return 0
}

checkhost() {
	local host="$1"

	[[ -n "$host" && ${#host} -le 253 ]] || return 1
	checkip "$host" && return 0

	[[ "$host" =~ ^[0-9.]+$ ]] && return 1

	[[ "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]
}

portfree() {
	local fn="${os}checkport"

	if declare -F "$fn" >/dev/null 2>&1; then
		"$fn" "$1"
	else
		return 0
	fi
}

findfreeport() {
	local port="${1:-${defaultport:-4444}}"
	local i

	[[ "$port" =~ ^[0-9]+$ ]] || port=4444

	for (( i = 0; i < 50; i++ )); do
		(( port > 65535 )) && break
		if portfree "$port"; then
			printf '%s\n' "$port"
			return 0
		fi
		port=$(( port + 1 ))
	done

	return 1
}


findip() {
	local ip=""

	case "$os" in
		linux)
			if have ip; then
				ip="$(ip -4 route get 1.1.1.1 2>/dev/null |
					awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
			fi
			if [[ -z "$ip" ]] && have hostname; then
				ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
			fi
			;;
		macos)
			if have route && have ipconfig; then
				local interface
				interface="$(route -n get default 2>/dev/null | awk '/interface: / {print $2; exit}')"
				if [[ -n "$interface" ]]; then
					ip="$(ipconfig getifaddr "$interface" 2>/dev/null)"
				fi
			fi
			;;
		windows)
			if have ipconfig; then
				ip="$(ipconfig 2>/dev/null | tr -d '\r' |
					awk -F': ' 'tolower($1) ~ /ipv4/ { gsub(/^ +| +$/, "", $2); print $2; exit }')"
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
	date '+%Y-%m-%d_%H-%M-%S'
}

nowstamp() {
	date '+%Y-%m-%d %H:%M:%S'
}

shorttime() {
	date '+%H:%M'
}

sesid() {
	local id

	id="$(od -An -N4 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"
	if [[ "$id" =~ ^[0-9a-f]{8}$ ]]; then
		printf '%s' "$id"
	else
		printf '%04x%04x' "$RANDOM" "$RANDOM"
	fi
}

validid() {
	[[ "$1" =~ ^[0-9a-f]{1,32}$ ]]
}


confirm() {
	local answer=""

	read -r -p "$1 [y/N]: " answer || return 1
	case "$answer" in
		y|Y|yes|YES|Yes) return 0 ;;
	esac
	return 1
}
