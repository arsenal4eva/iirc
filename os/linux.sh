#! /usr/bin/env bash

linuxinit() {
os="linux"

if ! command -v bash >/dev/null 2>&1; then
	error "Bash is required"
	return 1
fi

if ! command -v nc >/dev/null 2>&1; then
	warn "Nc is not installed"
	warn "Install using sudo apt install netcat-openbsd"
	return 1
fi

if ! command -v ip >/dev/null 2>&1; then
	warn "the ip command is not installed"
	return 1
fi

info "ur linux env is ready"
}


linuxcheckport() {
local port="$1"
if command -v ss >/dev/null 2>&1; then
	! ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"
elif command -v netstat >/dev/null 2>&1; then
	! netstat -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"
else
	warn "cannot check if port $port is in use"
	return 0
fi
}


linuxgetip() {
findip
}
