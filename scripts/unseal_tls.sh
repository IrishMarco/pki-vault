#!/bin/sh

set -e

if [ ! -f certs/client-vault-init/env-tls.sh -o ! -f certs/client-vault-init/vault-init-cert.pem -o ! -f certs/client-vault-init/vault-init-key.pem ]; then
  echo "you need to run first init_vault_server.sh"
  exit -2
fi

# Get environment variable
. ./certs/client-vault-init/env-tls.sh
# But use the root token for it!
ROOT_INIT=`gpg -d certs/root/vault_init.gpg | jq -r '.'`
export VAULT_TOKEN=`echo $ROOT_INIT | jq -r '.root_token'`

# Unseal the vault
# Get number of unseal_threshold
i=`echo $ROOT_INIT | jq '.unseal_threshold'`
until [ 1 -gt $i ]
do
  i=$((i-1))
  vault operator unseal `echo $ROOT_INIT  | jq -r '.unseal_keys_b64['$i']'`
done

