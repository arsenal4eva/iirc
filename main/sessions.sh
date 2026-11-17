#! /usr/bin/env bash


createsession() {
	local name type host port

	name="$(sanitize_text "$(trim "${1:-}")")"
	type="$(trim "${2:-}")"
	host="$(sanitize_text "$(trim "${3:-}")")"
	port="$(trim "${4:-}")"

	if [[ -z "$name" || -z "$type" || -z "$host" || -z "$port" ]]; then
		error "missing session info"
		return 1
	fi

	if [[ "$type" != "host" && "$type" != "connect" ]]; then
		error "invalid session type: $type"
		return 1
	fi

	if ! checkport "$port"; then
		error "invalid port: $port"
		return 1
	fi

	if ! checkhost "$host"; then
		error "invalid host: $host"
		return 1
	fi

	local id created sessionfile
	id="$(sesid)"
	created="$(getdate)"
	sessionfile="$sessiondir/$id.conf"

	mkdir -p "$sessiondir" || return 1

	(
		umask 077
		{
			printf 'id="%s"\n' "$id"
			printf 'name="%s"\n' "$name"
			printf 'type="%s"\n' "$type"
			printf 'host="%s"\n' "$host"
			printf 'port="%s"\n' "$port"
			printf 'status="stopped"\n'
			printf 'pid=""\n'
			printf 'created="%s"\n' "$created"
			printf 'logfile="%s"\n' "$logs/$id.log"
		} > "$sessionfile"
	) || {
		error "could not write session file"
		return 1
	}

	info "session created: $name" >&2
	printf '%s\n' "$id"
}

loadsession() {
	local id="$1"

	session_id=""
	session_name=""
	session_type=""
	session_host=""
	session_port=""
	session_status="stopped"
	session_pid=""
	session_created=""
	session_logfile=""

	if ! validid "$id"; then
		error "invalid session id: $id"
		return 1
	fi

	local sessionfile="$sessiondir/$id.conf"
	if [[ ! -f "$sessionfile" ]]; then
		error "session not found: $id"
		return 1
	fi

	local key value
	while IFS='=' read -r key value || [[ -n "$key" ]]; do
		key="$(trim "${key%$'\r'}")"
		value="${value%$'\r'}"
		value="${value#\"}"
		value="${value%\"}"

		case "$key" in
			id) session_id="$value" ;;
			name) session_name="$value" ;;
			type) session_type="$value" ;;
			host) session_host="$value" ;;
			port)
				if checkport "$value"; then
					session_port="$value"
				fi
				;;
			status) session_status="$value" ;;
			pid) session_pid="$value" ;;
			created) session_created="$value" ;;
			logfile) session_logfile="$value" ;;
		esac
	done < "$sessionfile"

	return 0
}

listsessions() {
	mkdir -p "$sessiondir"

	local files=("$sessiondir"/*.conf)
	if [[ ! -e "${files[0]}" ]]; then
		warn "no saved sessions"
		return 1
	fi

	printf '%-10s %-20s %-8s %-16s %-6s %s\n' "ID" "NAME" "TYPE" "HOST" "PORT" "STATUS"
	printf '%s\n' "--------------------------------------------------------------------------------"

	local found=0 id name type host port status pid live
	while IFS=$'\t' read -r id name type host port status pid; do
		[[ -n "$id" ]] || continue
		found=1

		live="$status"
		if [[ "$status" == "running" ]]; then
			if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
				live="running"
			else
				live="stopped"
			fi
		fi

		printf '%-10s %-20.20s %-8s %-16s %-6s %s\n' \
			"$id" "$name" "$type" "${host:--}" "${port:--}" "$live"
	done < <(
		awk -F'"' '
			function emit() {
				if (id != "")
					print id "\t" name "\t" type "\t" host "\t" port "\t" status "\t" pid
			}
			FNR == 1 {
				if (NR > 1)
					emit()
				id = name = type = host = port = status = pid = ""
			}
			$1 == "id=" { id = $2 }
			$1 == "name=" { name = $2 }
			$1 == "type=" { type = $2 }
			$1 == "host=" { host = $2 }
			$1 == "port=" { port = $2 }
			$1 == "status=" { status = $2 }
			$1 == "pid=" { pid = $2 }
			END { emit() }
		' "${files[@]}"
	)

	echo
	(( found == 1 ))
}

updatesession() {
	local id="$1"
	local key="$2"
	local value="$3"

	if ! validid "$id"; then
		error "invalid session id: $id"
		return 1
	fi

	local sessionfile="$sessiondir/$id.conf"
	if [[ ! -f "$sessionfile" ]]; then
		error "session not found: $id"
		return 1
	fi

	case "$key" in
		name)
			value="$(sanitize_text "$(trim "$value")")"
			[[ -n "$value" ]] || { error "empty session name"; return 1; }
			;;
		host)
			value="$(sanitize_text "$(trim "$value")")"
			checkhost "$value" || { error "invalid host: $value"; return 1; }
			;;
		status)
			case "$value" in
				running|stopped) ;;
				*) error "invalid status: $value"; return 1 ;;
			esac
			;;
		pid)
			if [[ -n "$value" && ! "$value" =~ ^[0-9]+$ ]]; then
				error "invalid pid: $value"
				return 1
			fi
			;;
		port)
			if ! checkport "$value"; then
				error "invalid port: $value"
				return 1
			fi
			;;
		type)
			if [[ "$value" != "host" && "$value" != "connect" ]]; then
				error "invalid session type: $value"
				return 1
			fi
			;;
		logfile)
			value="$(sanitize_text "$value")"
			;;
		*)
			error "invalid session field: $key"
			return 1
			;;
	esac

	local tmp
	tmp="$(mktemp "$sessiondir/.session.XXXXXX" 2>/dev/null)" || return 1

	awk -F'=' -v key="$key" -v value="$value" '
		$1 == key {
			printf "%s=\"%s\"\n", key, value
			found = 1
			next
		}
		{ print }
		END {
			if (!found)
				printf "%s=\"%s\"\n", key, value
		}
	' "$sessionfile" > "$tmp" || {
		rm -f "$tmp"
		return 1
	}

	chmod 600 "$tmp" 2>/dev/null || true
	mv -f "$tmp" "$sessionfile" || {
		rm -f "$tmp"
		return 1
	}
}

deletesession() {
	local id="$1"

	if ! validid "$id"; then
		error "invalid session id: $id"
		return 1
	fi

	local sessionfile="$sessiondir/$id.conf"
	if [[ ! -f "$sessionfile" ]]; then
		error "session not found: $id"
		return 1
	fi

	local logfile pid
	logfile="$(awk -F'"' '$1 == "logfile=" { print $2; exit }' "$sessionfile")"
	pid="$(awk -F'"' '$1 == "pid=" { print $2; exit }' "$sessionfile")"

	if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
		kill "$pid" 2>/dev/null || true
	fi

	rm -f "$sessionfile" || return 1

	if [[ -n "$logfile" && "$logfile" == "$logs"/* && -f "$logfile" ]]; then
		rm -f "$logfile"
	fi

	info "session deleted"
}

sessionexists() {
	validid "$1" && [[ -f "$sessiondir/$1.conf" ]]
}

initsessions() {
	mkdir -p "$sessiondir" || return 1
	chmod 700 "$sessiondir" 2>/dev/null || true
}
