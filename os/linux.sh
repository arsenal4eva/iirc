#! /usr/bin/env bash

linuxinit() {
	os="linux"

	if ! have bash; then
		error "bash is required"
		return 1
	fi

	if ! have nc && ! have ncat && ! have netcat; then
		warn "netcat is not installed"
		warn "install it with: sudo apt install netcat-openbsd"
		return 0
	fi

	if ! have ip && ! have hostname; then
		warn "could not find 'ip' or 'hostname'; ip detection may fail"
	fi

	info "linux environment is ready"
	return 0
}

linuxcheckport() {
	local port="$1"

	checkport "$port" || return 1

	if have ss; then
		ss -H -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$" && return 1
	elif have netstat; then
		netstat -lnt 2>/dev/null | awk 'NR > 2 {print $4}' | grep -Eq "[:.]${port}$" && return 1
	fi

	return 0
}

linuxgetip() {
	findip
}
