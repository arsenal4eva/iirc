#! /usr/bin/env bash


set -e

ver="1"
repoaddr="https://raw.githubusercontent.com/arsenal4eva/iirc/main"
dir="$HOME/.iirc"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
reset='\033[0m'

info() {
echo -e "${green}[+]${reset} $1"
}

warn() {
echo -e "${yellow}[!]${reset} $1"
}

error() {
echo -e "${red}[-]${reset} $1"
exit 1
}


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

OS="$(findos)"


echo 
echo "Thank you for downloading iirc"
echo "This is a project made by me (a 15 year old at the date of this release)"
echo "Feel free to open an issue or make pull requests on github!"
echo 


info "Current OS: $OS"

[[ "$OS" != "unsupported" ]] || error "Unsupported os."

command -v bash >/dev/null 2>&1 || error "Bash is required."

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
local remote="$1"
local destination="$2"
info "Download $remote"
if ! curl -fsSL "$repoaddr/$remote" -o "$destination"; then 
	error "Failed to download $remote"
fi
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
echo "iirc v$ver installed hooray"
echo 

echo "installed in $dir"
echo
echo "Run iirc using:"
echo
echo "	bash ~/.iirc/iirc.sh"
echo
