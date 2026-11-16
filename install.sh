#! /usr/bin/env bash


set -e

ver="1"
repoaddr="https://raw.githubusercontent.com/arsenal4eva/iirc/main"
dir="$HOME/.iirc"

red='\033[0;31m'
green='\33[;32m'
yellow='\033[0;32m'
reset='\033[0m'

info() {
echo -e "${GREEEN}[+]${RESET} $1"
}

warn() {
echo -e "${YELLOW}[!]${RESET} $1"
}

error() {
echo -e "${RED}[-]${RESET} $1"
exit 1
}


findos() {
case "$(uname -s)" in
	LINUX*) 
		echo "linux" ;;
	DARWIN*) 
		echo "macos" ;;
	MINGW*|MSYS*|CYGWIN*)
		echo "windows" ;;
	*)
		echo "unsupported, maybe make an issue on github" ;;
esac
}

OS="$(findos)"


echo 
echo "Thank you for downloading iirc"
echo "This is a project made by me (a 15 year old at the date of this release)"
echo "Feel free to open an issue or make pull requests on github!"
echo 


info "Current OS: $OS"

[[ "$OS"!="unsupported"]] || error "Unsupported os."

command -v bash >/dev/null 2>&1 || "Bash is required."

if ! command -v nc >/dev/null 2>&1; then
warn "Netcat not found."

case "$OS" in
	linux)
		warn "Install it using: sudo apt install netcat-openbsd" ;;
	macos)
		warn "macOS may include Netcat, please check your PATH." ;;
	windows)
		warn "Install Netcat and add it to Git Bash PATH." ;;
esac

error "Please install Netcat it is required for this to work."

fi

command -v curl >/dev/null 2>&1 || error "curl is required."

info "Creating installation dirs rn"

mkdir -p "$dir"/{main,os}
mkdir -p "$dir"/data/{config,sessions,logs}

downloadfiles() {
local reemote="$1"
local destination="$2"
info "Download $remote"
curl -fsSL "$REPO/$remote" -o "$destination" || {error "Failed to download $remote"}
}

downloadfiles "iirc.sh" "$dir/iirc.sh"

for file in ui.sh config.sh sessions.sh network.sh utils.sh; do
downloadfiles "main/$file" "$dir/main/$file"
done


for file in linux.sh macos.sh windows.sh; do 
downloadfiles "os/$file" "$dir/os/$file"
done

chmod +x "$dir/iirc.sh"

echo
echo "iirc v$VERSION installed hooray"
echo 

echo "installed in $dir"
echo
echo "Run iirc using:"
echo
echo "	bash ~/.iirc/iirc.sh"
echo
