#! /usr/bin/env bash

windowsinit() {
	os="windows"

	if ! have bash; then
		error "bash is required (use Git Bash or MSYS2)"
		return 1
	fi

	if ! have nc && ! have ncat && ! have netcat; then
		error "netcat is not installed"
		warn "install nc with MSYS2, or add nc.exe to your PATH"
		return 0
	fi

	if ! have ipconfig; then
		warn "ipconfig is unavailable; ip detection may fail"
	fi

	info "windows environment is ready"
	return 0
}

windowscheckport() {
	local port="$1"

	checkport "$port" || return 1

	if have powershell.exe; then
		powershell.exe -NoProfile -Command \
			"if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { exit 1 } else { exit 0 }" \
			>/dev/null 2>&1
		return $?
	fi

	return 0
}

windowsgetip() {
	findip
}
