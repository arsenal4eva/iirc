#! /usr/bin/env bash

networkpid=""

checknc() {
if ! command -v nc ./dev/null 2>&1; then
	error "nc is not installed"
	return 1
fi
}

startchat() {
local id="$1"
if [[ ! "$id" =~ ^[a-f0-9]+$ ]]; then
	error "invalid session id"
	return 1
fi
loadsession "$id" || return 1

if [[ "$session_type" != "host" ]]; then
	error "this session is not a hosted chat"
	return 1
fi

checknc || return 1

if [[ "$session_status" == "running" ]] && [[ -n "$session_pid" ]] && kill -0 "$session_pid" 2>/dev/null; then
	warn "chat is already running"
	return 1
fi

info "starting chat yippee"
info "waiting for someone to connect"

if [[ "$os" == "macos" ]]; then
	nc -l "$session_port" &
else
	nc -l -p "$session_port" &
fi

networkpid=$!
updatesession "$id" "status" "running"
updatesession "$id" "pid" "$networkpid"

wait "$networkpid"
local result=$?

updatesession "$id" "status" "stopped"
updatesession "$id" "pid" ""

return $result
}

connectchat() {
local id="$1"

if [[ ! "$id" =~ ^[a-f0-9]+$ ]]; then
	error "invalid session id"
	return 1
fi

loadsession "$id" || return 1

if  [[ "$session_type" != "connect" ]]; then
	error "this session is not a connection"
	return 1
fi

checknc || return 1

if ! checkip "$session_host"; then
	error "invalid ip"
	return 1
fi

info "connect to $session_host:$session_port"

nc "$session_host" "$session_port"
}

stopchat() {
local id="$1"

if [[ ! "$id" =~ ^[a-f0-9]+$ ]]; then
	error "invalid session id"
	return 1
fi

if kill -0 "$session_pid" 2>/dev/null; then
	kill "$session_pid" 2>/dev/null
	info "chat stopped"
else
	warn "chat is not running"
fi

updatesession "$id" "status" "stopped"
updatesession "$id" "pid" ""
}

networkinit(){
checknc || return 1
}

