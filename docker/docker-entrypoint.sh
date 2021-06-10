#!/usr/bin/dumb-init /bin/sh
set -e

# Note above that we run dumb-init as PID 1 in order to reap zombie processes
# as well as forward signals to all processes in its session. Normally, sh
# wouldn't do either of these functions so we'd leak zombies as well as do
# unclean termination of all our sub-processes.

# Prevent core dumps
ulimit -c 0

echo "127.0.0.1 vault.internal.local" >> /etc/hosts
if [ ! -f /vault/data/.initialized ]; then
  vault server -config /vault/scripts/vault-server-no-tls &
  until apk update; do sleep 3; done
  until apk add jq bash openssl gnupg; do sleep 3; done
  sleep 1
  /vault/scripts/init_vault_server.sh
  touch /vault/data/.initialized
  killall -9 vault
fi

exec vault server -config=/vault/config
