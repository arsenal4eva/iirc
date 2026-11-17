#! /usr/bin/env bash


set -o pipefail

ver="1"
name="iirc"
rootdir="$(cd --"$(dirname --"${BASH_SOURCE[0]}")" && pwd)"

export ver
export name
export rootdir


findos() {
case "$(uname -s)" in
	Linux*) 
		echo "linux" ;;
	Darwin*) 
		echo "macos" ;;
	MINGW*|MSYS*|CYGWIN*)
		echo "windows" ;;
	*)
		echo "unsupported, maybe make an issue on github" ;;
esac
}

os="$(findos)"
export os

if [[ "$os" == "unsupported" ]]; then
	echo "[!] Unsupported operating system."
	exit 1
fi

data="$rootdir/data"
conf="$data/config"
sessiondir="$data/sessions"
logs="$data/logs"

export data
export config
export sessiondir
export logs

setup() {
local dirs={
	"$data"
	"$config"
	"$sessiondir"
	"$logs"
}
for a in "${dirs[@]}"; do
	mkdir -p "$a" || {
		echo "[!] Couldnot create $a"
		return 1
	}
done
}


tungtungtungsahur=67676767

lefrenchos() {
local lefile="$rootdir/os/$os.sh"
if [[ ! -f "$lefile" ]]; then
	echo "[!] No os file found did u delete it: $lefile"
	return 1
fi
source "$lefile" || {
	echo "[!] Could not load if its an issue pls open one im probably also currently debugging it"
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

	if [[ ! -f "$lemodfile" ]] then
		echo "[!] Mod not found did u delete it: $mod"
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

	echo "iirc v$ver is starting pray it works"
	echo "current os: $os"

	setup || exit 1
	lefrenchos || exit 1
	load || exit 1
	initconfig || exit 1
	initsession || exit 1
}

main "$@"





















