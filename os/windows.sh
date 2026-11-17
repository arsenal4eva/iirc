#! /usr/bin/env bash

windowsinit() {
os="windows"
if ! command -v bash >/dev/null 2>&1; then
	error "Bash is required. u can use Git Bash or MSYS2"
	return 1
fi

if ! command -v nc >/dev/null 2>&1; then
	error "Nc is not installed"
	warn "install nc using MSYS2 or add nc.exe to ur Path"
	return 1
fi

if ! command -v ipconfig >/dev/null 2>&1; then
	error "ipconfig is unavailable"
	return 1
fi

info "windows env ready"
}

windowscheckport() {
local port="$1"
if ! chackport "$port"; then
	return 1
fi

if command -v powershell.exe >/dev/null 2>&1; then
	powershell.exe -NoProfile -Command \
		"if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { exit 1 } else { exit 0 }" \
		>/dev/null 2>&1
	return $?
fi

warn "Cannot check whether port $port is in use"
return 0
}

windowsgetip() {
findip
}
