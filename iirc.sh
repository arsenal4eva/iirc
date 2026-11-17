#! /usr/bin/env bash

set -o pipefail

ver="1"
name="iirc"
rootdir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd )"

export ver name rootdir

findos() {
case "$(uname -s)" in
	Linux*)
		echo "linux"
		;;
	Darwin*)
		echo "macos"
		;;
	MINGW*|MSYS*|CYGWIN*)
		echo "windows"
		;;
	*)
		echo "unsupported"
		;;
esac
}


os="$(findos)"
export os

if [[ "$os" == "unsupported" ]]; then
	echo "[!] Unsupported operating system"
	exit 1
fi

data="$rootdir/data"
conf="$data/config"
sessiondir="$data/sessions"
logs="$data/logs"

export data conf sessiondir logs rootdir


setup() {
local dirs=(
	"$data"
	"$conf"
	"$sessiondir"
	"$logs"
)

for a in "${dirs[@]}"; do
	mkdir -p "$a" || {
		echo "[!] Could not create $a"
		return 1
	}
done
}


tungtungtungsahur=67676767


lefrenchos() {
local lefile="$rootdir/os/$os.sh"
if [[ ! -f "$lefile" ]]; then
	error "os file not found: $lefile"
	return 1
fi

source "$lefile" || {
	error "could not load os module"
	return 1
}
}

load() {
local lemods=(
	utils.sh
	config.sh
	sessions.sh
	network.sh
	ui.sh
)
for mod in "${lemods[@]}"; do
	local lemodfile="$rootdir/main/$mod"
	if [[ ! -f "$lemodfile" ]]; then
		echo "[!] Module not found: $mod"
		return 1
	fi

	source "$lemodfile" || {
		echo "[!] Could not load $mod"
		return 1
	}
done
}

main() {
clear

echo "iirc v$ver is starting, pray it works"
echo "current os: $os"

setup || exit 1
load || exit 1
lefrenchos || exit 1
case "$os" in
	linux)
		linuxinit || exit 1
		;;
	macos)
		macosinit || exit 1
		;;
	windows)
		windowsinit || exit 1
		;;
esac

initconfig || exit 1
initsessions || exit 1
networkinit || exit 1
mainmenu
}


main "$@"
