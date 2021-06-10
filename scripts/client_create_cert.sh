#!/bin/bash

set -eu

if [ "$1" == "" ]; then
  echo "usage: $0 <client domain>"
  exit -1
fi

if [ ! -f certs/client-vault-init/env-tls.sh -o ! -f certs/client-vault-init/vault-init-cert.pem -o ! -f certs/client-vault-init/vault-init-key.pem ]; then
  echo "you need to run first create_vault_server.sh"
  exit -2
fi

. ./certs/client-vault-init/env-tls.sh

#
# Create client CA & key
#
CA_CLIENT=$1

cat << EOF > payload.json
{
  "common_name": "$CA_CLIENT.internal.local"
}
EOF

mkdir -p certs/client-$CA_CLIENT
curl --cacert certs/client-vault-init/ca_chain.pem       \
     --cert certs/client-vault-init/vault-init-cert.pem  \
     --key certs/client-vault-init/vault-init-key.pem    \
     -H "X-Vault-Token: $VAULT_TOKEN"                    \
     --request POST --data @payload.json                 \
     -s $VAULT_ADDR/v1/pki_int/issue/internal-dot-local | jq '.' > certs/client-$CA_CLIENT/$CA_CLIENT.json
cat certs/client-$CA_CLIENT/$CA_CLIENT.json | jq -r '.data.certificate' > certs/client-$CA_CLIENT/$CA_CLIENT-cert.pem
cat certs/client-$CA_CLIENT/$CA_CLIENT.json | jq -r '.data.private_key' > certs/client-$CA_CLIENT/$CA_CLIENT-key.pem
cat certs/client-$CA_CLIENT/$CA_CLIENT.json | jq -r '.data.issuing_ca' >  certs/client-$CA_CLIENT/ca.pem
cat certs/client-$CA_CLIENT/$CA_CLIENT.json | jq -r '.data.ca_chain[]' >  certs/client-$CA_CLIENT/ca_chain.pem
# Create the pkcs12 for browser
echo "Enter a password: do not forget it as it will be needed when loading the certificate on Firefox/Chrome..."
openssl pkcs12 -export -in certs/client-$CA_CLIENT/$CA_CLIENT-cert.pem -inkey certs/client-$CA_CLIENT/$CA_CLIENT-key.pem -out certs/client-$CA_CLIENT/$CA_CLIENT.p12

# Clean up
rm payload.json
