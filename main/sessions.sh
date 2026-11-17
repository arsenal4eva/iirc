#! /usr/bin/env bash

sessiondir="$rootdir/data/sessions"

createsession() {
local name="$1"
local type="$2"
local host="$3"
local port="$4"

if [[ -z "$name" || -z "$type" || -z "$host" || -z "$port" ]]; then
	error "missing session info"
	return 1
fi

if [[ "$type" != "host" && "$type" != "connect" ]]; then
	error "invalid session type"
	return 1
fi

if ! chackport "$port"; then
	error "invalid port"
	return 1
fi

local id
id="$(sesid)"

local created
created="$(getdate)"
local sessionfile
sessionfile="$sessiondir/$id.conf"
mkdir -p "$sessiondir"
cat > "$sessionfile" <<EOF
id="$id"
name="$name"
type="$type"
host="$host"
port="$port"
status="stopped"
pid=""
created="$created"
logfile="$rootdir/data/logs/$id.log"
EOF

info "session created: $name"
printf '%s\n' "$id"
}

loadsession() {
local id="$1"
	
if [[ ! "$id" =~ ^[a-f0-9]+$ ]]; then
	error "invalid session id"
	return 1
fi

local sessionfile="$sessiondir/$id.conf"

if [[ ! -f "$sessionfile" ]]; then
	error "session not found"
	return 1
fi

while IFS='=' read -r key value; do
	value="${value%\"}"
	value="${value#\"}"

	case "$key" in
		id) session_id="$value";;
		name) session_name="$value" ;;
		type) session_type="$value" ;;
		host) session_host="$value" ;;
		port)
			if chackport "$value"; then
				session_port="$value"
			fi
			;;
		status) session_status="$value" ;;
		pid) session_pid="$value" ;;
		created) session_created="$value" ;;
		logfile) session_logfile="$value" ;; 
	esac
done < "$sessionfile"
}


listsessions() {
mkdir -p "$sessiondir"
local found=false
printf 'n%-12s %-20s %-18s %-8s\n' "ID" "NAME" "TYPE" "HOST" "PORT"

printf '%s\n' "--------------------------------------------------------------------------"
for sessionfile in "$sessiondir"/*.conf; do
	[[ -f "$sessionfile" ]] || continue
	local id name type host port
	id=""
	name=""
	type=""
	host=""
	port=""

	while IFS='=' read -r key value; do
		value="${value%\"}"
		value="${value#\"}"

		case "$key" in
			id) id="$value" ;;
			name) name="$value" ;;
			type) type="$value" ;;
			host) host="$value" ;;
			port) port="$value" ;;
		esac
	done < "$sessionfile"
	printf '%-12s %-20.20s %-10s %-18s %-8s\n' "$id" "$name" "$type" "$host" "$port"

	found=true
done

if [[ "$found" == false ]]; then
	warn "no saved sessions"
fi

echo

}

updatesession() {
local id="$1"
local key="$2"
local value="$3"

if [[ ! "$id" =~ ^[a-f0-9]+$ ]]; then
	error "invalid session id"
	return 1
fi

local sessionfile="$sessiondir/$id.conf"

if [[ ! -f "$sessionfile" ]]; then
	error "session not found"
	return 1
fi

case "$key" in
	name|host|status|pid|logfile)
		;;
	port)
		if !chackport "$value"; then
			error "invalid port"
			return 1
		fi
		;;
	type)
		if [[ "$value" != "host" && "$value" != "connect" ]]; then
			error "invalid session type"
			return 1
		fi
		;;
	*)
		error "invalid session field"
		return 1
		;;
esac

local tempfile
tempfile="$(mktemp)" || return 1

awk -F= -v key="$key" -v value="$value" '
	$1 == key {
		print key "=\"" value "\""
		found=1
		next
	}
	{print}
	END {
		if (!found) print key "=\"" value "\""
	}
' "$sessionfile" > "$tempfile"
mv "$tempfile" "$sessionfile"
}


deletesession() {
local id="$1"

if [[ ! "$id" =~ ^[a-f0-9]+$ ]]; then
	error "invalid session id"
	return 1
fi

local sessionfile="$sessiondir/$id.conf"

if [[ ! -f "$sessionfile" ]]; then
	error "session notf ound"
	return 1
fi

rm -rf "$sessionfile"
info "session has been deletd"
}


initsessions() {
mkdir -p "$sessiondir"
}
