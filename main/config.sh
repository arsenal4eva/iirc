#!/usr/bin/env bash


setdefaults() {
	username="${USER:-${LOGNAME:-user}}"
	defaultport="4444"
	timestamps="true"
	save_logs="true"
	auto_reconnect="false"
}

normalise_bool() {
	local value

	value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
	case "$value" in
		true|1|yes|on) printf 'true'; return 0 ;;
		false|0|no|off) printf 'false'; return 0 ;;
	esac
	return 1
}

setusername() {
	local name
	local old="$username"

	name="$(sanitize_text "$(trim "$1")")"
	[[ -n "$name" ]] || return 1

	username="${name:0:32}"
	[[ -n "$(trim "$username")" ]] || { username="$old"; return 1; }
	return 0
}

createconfig() {
	[[ -f "$configfile" ]] || {
		info "Creating default config"
		setdefaults
		saveconfig quiet
	}
}

loadconfig() {
	setdefaults

	createconfig

	local key value
	while IFS='=' read -r key value || [[ -n "$key" ]]; do
		key="$(trim "${key%$'\r'}")"
		value="$(trim "${value%$'\r'}")"

		[[ -z "$key" || "$key" == \#* ]] && continue
		key="${key#export }"

		value="${value#\"}"
		value="${value%\"}"
		value="${value#\'}"
		value="${value%\'}"

		case "$key" in
			username)
				setusername "$value" || true
				;;
			defaultport)
				if checkport "$value"; then
					defaultport="$value"
				fi
				;;
			timestamps)
				value="$(normalise_bool "$value")" && timestamps="$value"
				;;
			save_logs)
				value="$(normalise_bool "$value")" && save_logs="$value"
				;;
			auto_reconnect)
				value="$(normalise_bool "$value")" && auto_reconnect="$value"
				;;
		esac
	done < "$configfile"
}

saveconfig() {
	local quiet="${1:-}"

	mkdir -p "$(dirname "$configfile")" || return 1

	local tmp
	tmp="$(mktemp "${configfile}.XXXXXX" 2>/dev/null)" || return 1

	{
		printf 'username="%s"\n' "$username"
		printf 'defaultport="%s"\n' "$defaultport"
		printf 'timestamps="%s"\n' "$timestamps"
		printf 'save_logs="%s"\n' "$save_logs"
		printf 'auto_reconnect="%s"\n' "$auto_reconnect"
	} > "$tmp" || {
		rm -f "$tmp"
		return 1
	}

	chmod 600 "$tmp" 2>/dev/null || true
	mv -f "$tmp" "$configfile" || {
		rm -f "$tmp"
		return 1
	}

	[[ "$quiet" == "quiet" ]] || info "Config saved"
}

initconfig() {
	mkdir -p "$(dirname "$configfile")" || return 1

	createconfig
	loadconfig

	info "Config loaded"
}
