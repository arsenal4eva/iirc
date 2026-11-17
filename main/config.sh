#!/usr/bin/env bash

configfile="$conf/settings.conf"

setdefaults() {
    username="${USER:-user}"
    defaultport="4444"
    timestamps="true"
    save_logs="true"
    auto_reconnect="false"
}

createconfig() {
if [[ ! -f "$configfile" ]]; then
    info "Creating default configs"

    setdefaults

cat > "$configfile" <<EOF
username="$username"
defaultport="$defaultport"
timestamps="$timestamps"
save_logs="$save_logs"
auto_reconnect="$auto_reconnect"
EOF
fi
}

loadconfig() {
    setdefaults

    if [[ ! -f "$configfile" ]]; then
        createconfig
    fi

    while IFS='=' read -r key value; do

        value="${value%\"}"
        value="${value#\"}"

        case "$key" in
            username)
                username="$value"
                ;;
            defaultport)
                if chackport "$value"; then
                    defaultport="$value"
                fi
                ;;
            timestamps)
                timestamps="$value"
                ;;
            save_logs)
                save_logs="$value"
                ;;
            auto_reconnect)
                auto_reconnect="$value"
                ;;
        esac

    done < "$configfile"
}

saveconfig() {
cat > "$configfile" <<EOF
username="$username"
defaultport="$defaultport"
timestamps="$timestamps"
save_logs="$save_logs"
auto_reconnect="$auto_reconnect"
EOF

info "Config saved"
}

initconfig() {
mkdir -p "$(dirname "$configfile")"

createconfig
loadconfig

info "Config loaded"
}
