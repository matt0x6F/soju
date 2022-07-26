#!/usr/bin/env bash

# setup defaults
if [[ -n "${TLS_CERT}" && -n "${TLS_KEY}" ]]; then
    USE_TLS=true
    PORT="${PORT:-6697}"
else
    USE_TLS=false
    PORT="${PORT:-6667}"
fi

SOJU_HOST="${SOJU_HOST:-${HOSTNAME}}"

if [[ ! -f /data/soju.cfg ]]; then
    (
        if "${USE_TLS}"; then
            echo "listen ircs://0.0.0.0:${PORT}"
            echo "tls ${TLS_CERT} ${TLS_KEY}"
        else
            echo "listen irc+insecure://0.0.0.0:${PORT}"
        fi
        echo "hostname ${SOJU_HOST}"
        echo "db sqlite3 /data/soju.db"
    ) > /data/soju.cfg
fi

# @todo: does not create user
grep '^user ' <<< "${SOJU_INIT}" | while read -r _ user password admin; do
    echo "${password}" | /app/sojuctl -config /data/soju.cfg create-user "${user}" "${admin:+-admin}"
done

/app/soju -config /data/soju.cfg &

port_open=false

for _ in $(seq 1 6); do
    if nc -z localhost "${PORT}"; then
        echo "irc port open!"
        port_open=true
        break
    fi

    echo "waiting for irc port to open"
    sleep 5
done

if ! ${port_open}; then
    echo "timeout waiting for irc port to open" >&2
    exit 1
fi

grep '^user ' <<< "${SOJU_INIT}" | while read -r _ user password _; do
    (
        echo "PASS ${password}"
        echo "NICK ${user}"
        echo "USER ${user} 8 * :${user}"

        grep "^server ${user} " <<< "${SOJU_INIT}" | while read -r _ _ server_name server_addr server_nick; do
            echo "PRIVMSG BouncerServ : network create -name ${server_name} -addr ${server_addr} -nick ${server_nick}"

            sleep 3

            grep "^channels ${user} ${server_name} " <<< "${SOJU_INIT}" | while read -r _ _ _ channels; do
                for c in ${channels}; do
                    echo "JOIN ${c}/${server_name}"
                done
            done
        done

        sleep 10
    ) | {
        if "${USE_TLS}"; then
            openssl s_client "localhost:${PORT}"
        else
            nc localhost "${PORT}"
        fi
    }
done 

wait
