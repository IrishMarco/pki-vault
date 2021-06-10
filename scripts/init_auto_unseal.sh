#!/bin/bash

# This script is launched in the same container instance
# to undeal when ready

if [ "$UNSEAL_SECRET" == "" ]; then
  echo "Incorrect configuration: cannot retrieve the unseal meta-data"
  exit
fi

if [ ! -f certs/client-vault-init/env-tls.sh -o ! -f certs/client-vault-init/vault-init-cert.pem -o ! -f certs/client-vault-init/vault-init-key.pem ]; then
  echo "you need to run first init_vault_server.sh"
  exit -2
fi

# Get environment variable for TLS connection
. ./certs/client-vault-init/env-tls.sh

# wait for the vault to be up and running
while [ true ]; do
  vault status > /dev/null
  case $? in
    1) echo "Cannot reach the vault";;
    2) echo "Vault up and running - Sealed" ; break;;
    0) echo "Vault already up and unsealed" ; exit 0;;
    *) echo "Unknown return states";;
  esac
  sleep 1
done

# Get the root token for it!
export VAULT_TOKEN=`echo $UNSEAL_SECRET | jq -r '.root_token'`

# Unseal the vault
# Get number of unseal_threshold
i=`echo $UNSEAL_SECRET | jq '.unseal_threshold'`
until [ 1 -gt $i ]
do
  i=$((i-1))
  vault operator unseal `echo $UNSEAL_SECRET  | jq -r '.unseal_keys_b64['$i']'`
done

# Check everything is OK
sleep 2
vault status > /dev/null
case $? in
  1) echo "Cannot reach the vault";;
  2) echo "Error: Vault still sealed";;
  0) echo "Good";;
  *) echo "Unknown return states";;
esac
