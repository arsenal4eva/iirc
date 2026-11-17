#! /usr/bin/env bash

macosinit() {
	os="macos"

	if ! have bash; then
		error "bash is required"
		return 1
	fi

	if ! have nc && ! have ncat; then
		error "netcat is not installed"
		warn "netcat ships with macOS; check your PATH"
		return 0
	fi

	if ! have route; then
		warn "the route command is unavailable; ip detection may fail"
	fi

	info "macOS environment is good to go"
	return 0
}

macoscheckport() {
	local port="$1"

	checkport "$port" || return 1

	if have lsof; then
		lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1 && return 1
	fi

	return 0
}

macosgetip() {
	findip
}
