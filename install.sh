#! /usr/bin/env bash

set -euo pipefail

ver="2"
repo="${IIRC_REPO:-https://raw.githubusercontent.com/arsenal4eva/iirc/main}"
dir="${IIRC_HOME:-$HOME/.iirc}"
bindir="${IIRC_BIN:-$HOME/.local/bin}"
files=(
	"iirc.sh"
	"main/utils.sh"
	"main/config.sh"
	"main/sessions.sh"
	"main/network.sh"
	"main/ui.sh"
	"os/linux.sh"
	"os/macos.sh"
	"os/windows.sh"
)

if [[ -z "${NO_COLOR:-}" ]]; then
	red=$'\033[0;31m'
	green=$'\033[0;32m'
	yellow=$'\033[1;33m'
	reset=$'\033[0m'
else
	red=''
	green=''
	yellow=''
	reset=''
fi

info() { printf '%s[+]%s %s\n' "$green" "$reset" "$*"; }
warn() { printf '%s[!]%s %s\n' "$yellow" "$reset" "$*" >&2; }
error() { printf '%s[-]%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }

findos() {
	case "$(uname -s)" in
		Linux*) echo "linux" ;;
		Darwin*) echo "macos" ;;
		MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
		*) echo "unsupported" ;;
	esac
}

usage() {
	cat <<EOF
iirc installer v$ver

Usage: install.sh [--uninstall] [--help]

Environment:
  IIRC_REPO   repository base URL (default: $repo)
  IIRC_HOME   install directory (default: $dir)
  IIRC_BIN    launcher directory (default: $bindir)
EOF
}

uninstall() {
	if [[ ! -d "$dir" ]]; then
		warn "nothing to uninstall in $dir"
		return 0
	fi

	printf 'Remove %s and all saved sessions/logs? [y/N]: ' "$dir"
	read -r answer || answer=""
	case "$answer" in
		y|Y|yes|YES) ;;
		*) info "aborted"; return 0 ;;
	esac

	rm -rf "$dir"
	rm -f "$bindir/iirc"
	info "iirc removed"
}

case "${1:-}" in
	-h|--help) usage; exit 0 ;;
	--uninstall) uninstall; exit 0 ;;
	"") ;;
	*) error "unknown option: $1" ;;
esac

OS="$(findos)"

echo
echo "Thank you for downloading iirc"
echo "This is a project made by me (a 15 year old at the date of this release)"
echo "Feel free to open an issue or make pull requests on github!"
echo

info "Current os: $OS"

[[ "$OS" != "unsupported" ]] || error "unsupported operating system: $(uname -s)"

command -v bash >/dev/null 2>&1 || error "bash is required"

if [[ "${BASH_VERSINFO[0]}" -lt 3 ]] || { [[ "${BASH_VERSINFO[0]}" -eq 3 ]] && [[ "${BASH_VERSINFO[1]}" -lt 2 ]]; }; then
	error "bash 3.2 or newer is required (found $BASH_VERSION)"
fi

CURL=""
WGET=""
if command -v curl >/dev/null 2>&1; then
	CURL="curl"
elif command -v wget >/dev/null 2>&1; then
	WGET="wget"
else
	error "curl or wget is required"
fi

if ! command -v nc >/dev/null 2>&1 && ! command -v ncat >/dev/null 2>&1 && ! command -v netcat >/dev/null 2>&1; then
	warn "netcat was not found, chatting will not work until it is installed"
	case "$OS" in
		linux) warn "install it with: sudo apt install netcat-openbsd" ;;
		macos) warn "netcat ships with macOS; check your PATH" ;;
		windows) warn "install nc with MSYS2, or add nc.exe to your PATH" ;;
	esac
fi

info "Creating installation directories"

mkdir -p "$dir/main" "$dir/os"
mkdir -p "$dir/data/config" "$dir/data/sessions" "$dir/data/logs"
chmod 700 "$dir/data" "$dir/data/config" "$dir/data/sessions" "$dir/data/logs" 2>/dev/null || true

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/iirc-install.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

copy_file() {
	local mode="$1"
	local src="$2"
	local dst="$3"

	if command -v install >/dev/null 2>&1; then
		install -m "$mode" "$src" "$dst"
	else
		cp -f "$src" "$dst"
		chmod "$mode" "$dst"
	fi
}

download() {
	local remote="$1"
	local destination="$2"

	info "Downloading $remote"

	if [[ -n "$CURL" ]]; then
		"$CURL" -fsSL --retry 3 --retry-delay 1 "$repo/$remote" -o "$destination"
	else
		"$WGET" -qO "$destination" "$repo/$remote"
	fi

	[[ -s "$destination" ]] || error "downloaded file is empty: $remote"
}

for file in "${files[@]}"; do
	mkdir -p "$tmpdir/$(dirname "$file")"
	download "$file" "$tmpdir/$file"
done

info "Installing files"
copy_file 755 "$tmpdir/iirc.sh" "$dir/iirc.sh"

for file in main/utils.sh main/config.sh main/sessions.sh main/network.sh main/ui.sh; do
	copy_file 644 "$tmpdir/$file" "$dir/$file"
done

for file in os/linux.sh os/macos.sh os/windows.sh; do
	copy_file 644 "$tmpdir/$file" "$dir/$file"
done

if mkdir -p "$bindir" 2>/dev/null; then
	launcher="$bindir/iirc"
	{
		printf '#!/usr/bin/env bash\n'
		printf 'exec bash %q "$@"\n' "$dir/iirc.sh"
	} > "$launcher"
	chmod 755 "$launcher"
	info "Launcher installed at $launcher"
else
	warn "could not create $bindir; run the app with: bash $dir/iirc.sh"
fi

echo
echo "iirc v$ver installed hooray"
echo
echo "installed in $dir"

case ":$PATH:" in
	*":$bindir:"*) ;;
	*)
		echo
		warn "$bindir is not in your PATH"
		echo "	add this to your shell rc file:"
		echo "	export PATH=\"$bindir:\$PATH\""
		;;
esac

echo
echo "Run iirc using:"
echo
echo "	iirc"
echo "	# or"
echo "	bash $dir/iirc.sh"
echo
