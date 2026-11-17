#! /usr/bin/env bash

set -o pipefail

ver="2"
name="iirc"

rootdir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

data="${IIRC_DATA:-$rootdir/data}"
confdir="$data/config"
conf="$confdir"
configfile="$confdir/settings.conf"
sessiondir="$data/sessions"
logs="$data/logs"

export ver name rootdir data confdir conf configfile sessiondir logs


findos() {
	case "$(uname -s)" in
		Linux*) echo "linux" ;;
		Darwin*) echo "macos" ;;
		MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
		*) echo "unsupported" ;;
	esac
}

os="$(findos)"
export os

if [[ "$os" == "unsupported" ]]; then
	error() { printf '%s[-]%s %s\n' "${red:-}" "${reset:-}" "$*" >&2; }
	error "unsupported operating system: $(uname -s)"
	exit 1
fi


setup() {
	local dirs=(
		"$data"
		"$confdir"
		"$sessiondir"
		"$logs"
	)
	local dir

	for dir in "${dirs[@]}"; do
		mkdir -p "$dir" || {
			echo "[!] Could not create $dir" >&2
			return 1
		}
	done

	chmod 700 "$data" "$confdir" 2>/dev/null || true
	chmod 700 "$sessiondir" "$logs" 2>/dev/null || true
}

lefrenchos() {
	local osfile="$rootdir/os/$os.sh"

	if [[ ! -f "$osfile" ]]; then
		error "os module not found: $osfile"
		return 1
	fi

	source "$osfile" || {
		error "could not load os module"
		return 1
	}
}

load() {
	local mods=(
		utils.sh
		config.sh
		sessions.sh
		network.sh
		ui.sh
	)
	local mod modfile

	for mod in "${mods[@]}"; do
		modfile="$rootdir/main/$mod"

		if [[ ! -f "$modfile" ]]; then
			error "module not found: $mod"
			return 1
		fi

		source "$modfile" || {
			error "could not load $mod"
			return 1
		}
	done
}

osinit() {
	local fn="${os}init"

	if ! declare -F "$fn" >/dev/null 2>&1; then
		error "no init function for $os"
		return 1
	fi

	"$fn"
}


usage() {
	cat <<EOF
iirc v$ver - a way for two people to chat

Usage:
  iirc.sh                          interactive menu
  iirc.sh --host [PORT] [NAME]     host a chat
  iirc.sh --connect HOST[:PORT] [NAME]
                                   connect to a chat
  iirc.sh --list                   list saved sessions
  iirc.sh --version
  iirc.sh --help

Environment:
  IIRC_DATA             data directory (default: $rootdir/data)
  IIRC_NC_LISTEN_ARGS   override netcat listen arguments
  IIRC_CONNECT_RETRIES  connection attempts (default: 5)
  NO_COLOR              disable colours

Config and logs live in $data.
EOF
}

version() {
	printf 'iirc v%s\n' "$ver"
}

show_host_info() {
	local ip port
	ip="$(findip || true)"
	port="$1"

	echo
	info "Share this address with the other person:"
	printf '%s:%s\n' "${ip:-your-ip}" "$port"
	echo
}

cmd_host() {
	local port="${1:-$defaultport}"
	local sname="${2:-host-$port}"
	local id

	if ! checkport "$port"; then
		error "invalid port: $port"
		return 1
	fi

	if ! portfree "$port"; then
		error "port $port is already in use"
		return 1
	fi

	id="$(createsession "$sname" "host" "0.0.0.0" "$port")" || return 1

	printf 'Session id: %s\n' "$id"
	show_host_info "$port"

	startchat "$id"
}

cmd_connect() {
	local target="${1:-}"
	local port="${2:-$defaultport}"
	local sname="${3:-}"
	local host id

	if [[ -z "$target" ]]; then
		error "missing host"
		usage
		return 1
	fi

	if [[ "$target" == *:* && "$target" != *::* ]]; then
		host="${target%%:*}"
		port="${target##*:}"
	else
		host="$target"
	fi

	if ! checkhost "$host"; then
		error "invalid host: $host"
		return 1
	fi

	if ! checkport "$port"; then
		error "invalid port: $port"
		return 1
	fi

	[[ -n "$sname" ]] || sname="client-$host"

	id="$(createsession "$sname" "connect" "$host" "$port")" || return 1

	printf 'Session id: %s\n' "$id"

	connectchat "$id"
}


main() {
	case "${1:-}" in
		-h|--help)
			usage
			return 0
			;;
		-V|--version)
			version
			return 0
			;;
	esac

	setup || exit 1
	load || exit 1
	lefrenchos || exit 1
	osinit || exit 1
	initconfig || exit 1
	initsessions || exit 1
	networkinit || true

	case "${1:-}" in
		"")
			if [[ ! -t 0 ]]; then
				usage
				exit 1
			fi
			mainmenu
			;;
		-l|--list)
			listsessions || true
			;;
		--host)
			shift
			cmd_host "$@"
			;;
		--connect)
			shift
			cmd_connect "$@"
			;;
		*)
			error "unknown option: $1"
			usage
			exit 1
			;;
	esac
}


main "$@"
