#! /usr/bin/env bash

macosinit() {
os="macos"
if ! command -v bash >/dev/null 2>&1; then
	error "Bash is required"
	return 1
fi

if ! command -v nc >/dev/null 2>&1; then
	error "Nc is not installed"
	warn "Nc should come with macos by default"
	return 1
fi

if ! command -v route >/dev/null 2>&1; then
	error "the route command is unavailable"
	return 1
fi

info "your macos env is good to go"
}


macoscheckport() {
local port="$1"

if ! chackport "$port"; then
	return 1
fi

if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then 
	return 1
fi

return 0
}

macosgetip() {
findip
}


