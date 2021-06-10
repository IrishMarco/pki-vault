#!/bin/bash

set -eux

#
# Update /etc/hosts with
#   127.0.0.1   vault.internal.local
#
#  First boot:
#    - create the vault instance without TLS
#    - initialize it
#    - create root cert and intermediate
#    - create client cert to interact with vault
#    - unseal it if needed
#           
unset VAULT_SERVER_DOMAIN VAULT_TOKEN VAULT_CLIENT_CERT VAULT_CACERT VAULT_ADDR VAULT_CLIENT_KEY

CN_DOMAIN="PersonalCloud"
ALLOWED_DOMAIN="internal.local"
VAULT_SERVER_DOMAIN="vault.$ALLOWED_DOMAIN"
VAULT_CONFIGURATION="/vault/certs/root/vault_init.gpg"
export VAULT_ADDR="http://$VAULT_SERVER_DOMAIN:8200"

# Start gpg daemon and add the key
eval $(gpg-agent --daemon)
gpg --auto-key-locate keyserver --keyserver keyserver.ubuntu.com --locate-keys $GPG_RECIPIENT

# Got to the default directory
cd /vault

####################
# Initialize vault #
####################

# production only
mkdir -p certs/root
RESULT_VAULT=$(vault operator init -format=json)
export VAULT_TOKEN=`echo $RESULT_VAULT | jq -r '.root_token'`

# Unseal the vault
# Get number of unseal_threshold
i=`echo $RESULT_VAULT | jq '.unseal_threshold'`
until [ 1 -gt $i ]
do
  i=$((i-1))
  vault operator unseal `echo $RESULT_VAULT | jq -r '.unseal_keys_b64['$i']'`
done

# Ecnrypt the file and cleanup
echo $RESULT_VAULT | gpg --batch --always-trust --output $VAULT_CONFIGURATION --encrypt $(echo $GPG_RECIPIENT | tr " " "\n" | xargs -n1 -I{} echo "--recipient={}")
killall -q gpg-agent

##################
# Initialize PKI #
##################

# Init PKI
vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki

# Generate self signed CA
vault write -format=json pki/root/generate/internal common_name="$CN_DOMAIN Root CA" ttl=87600h > certs/root/CA_cert.json
cat certs/root/CA_cert.json | jq -r '.data.csr' > certs/root/CA_cert.pem

# Configure CRL
vault write pki/config/urls issuing_certificates="https://$VAULT_SERVER_DOMAIN:8200/v1/pki/ca" crl_distribution_points="https://$VAULT_SERVER_DOMAIN:8200/v1/pki/crl"


################
# Intermediate #
################

# Init intermdiate CA
vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=43800h pki_int

# Generate intermdiate CA
vault write -format=json pki_int/intermediate/generate/internal common_name="$CN_DOMAIN Intermediate Authority" ttl=43800h > certs/root/pki_int.json
cat certs/root/pki_int.json | jq -r '.data.csr' > certs/root/pki_int.csr

# Sign it
vault write -format=json pki/root/sign-intermediate csr=@certs/root/pki_int.csr format=pem_bundle ttl=43800h > certs/root/signed_certificate.json
cat certs/root/signed_certificate.json  | jq -r '.data.certificate' > certs/root/signed_certificate.pem

# Add it to the vault
vault write pki_int/intermediate/set-signed certificate=@certs/root/signed_certificate.pem

# Configure URL
vault write pki_int/config/urls issuing_certificates="https://vault.internal.local:8200/v1/pki_int/ca" crl_distribution_points="https://vault.internal.local:8200/v1/pki_int/crl"

########
# Role #
########

# Create
vault write pki_int/roles/internal-dot-local  allowed_domains="$ALLOWED_DOMAIN"  allow_subdomains=true max_ttl=72h

################################
# Create vault server CA & key #
#  this keys must be added to the server and the HCL file #
################################
CA_CLIENT=vault
mkdir -p certs/server-certs
vault write -format=json pki_int/issue/internal-dot-local  common_name="$CA_CLIENT.internal.local" ip_sans="127.0.0.1" > certs/server-certs/$CA_CLIENT.json
cat certs/server-certs/$CA_CLIENT.json | jq -r '.data.certificate' > certs/server-certs/vault_cert.pem
cat certs/server-certs/$CA_CLIENT.json | jq -r '.data.private_key' > certs/server-certs/vault_key.pem
cat certs/server-certs/$CA_CLIENT.json | jq -r '.data.issuing_ca'  > certs/server-certs/ca.pem
cat certs/server-certs/$CA_CLIENT.json | jq -r '.data.ca_chain[]'  > certs/server-certs/ca_chain.pem

# Get the public CA and Intermediate cert
mkdir -p certs/public
vault read --format=json pki/cert/ca  | jq -r '.data.certificate'           > certs/public/CA_public.pem
vault read --format=json pki_int/cert/ca_chain  | jq -r '.data.certificate' > certs/public/Intermediate_public.pem

# Transform them in CRT
openssl x509 -outform der -in certs/public/CA_public.pem -out certs/public/CA_public.crt
openssl x509 -outform der -in certs/public/Intermediate_public.pem -out certs/public/Intermediate_public.crt

###############################################################
# Create the certificate used by other devices to create cert #
###############################################################
# Create root vault access
CA_CLIENT=vault-init
mkdir -p certs/client-$CA_CLIENT
vault write -format=json pki_int/issue/internal-dot-local common_name="$CA_CLIENT.internal.local" > certs/client-$CA_CLIENT/$CA_CLIENT.json
cat certs/client-$CA_CLIENT/$CA_CLIENT.json | jq -r '.data.certificate' > certs/client-$CA_CLIENT/$CA_CLIENT-cert.pem
cat certs/client-$CA_CLIENT/$CA_CLIENT.json | jq -r '.data.private_key' > certs/client-$CA_CLIENT/$CA_CLIENT-key.pem
cat certs/client-$CA_CLIENT/$CA_CLIENT.json | jq -r '.data.issuing_ca' >  certs/client-$CA_CLIENT/ca.pem
cat certs/client-$CA_CLIENT/$CA_CLIENT.json | jq -r '.data.ca_chain[]' >  certs/client-$CA_CLIENT/ca_chain.pem

# Create the profile and the token the clients
# Do all policies
for x in policies/*.hcl; do
  policy="${x##*/}"
  policy="${policy%.*}"
  echo "Apply policy $policy"
  vault policy write "${policy}" - < $x
done

# Create a role for creating certificate
VAULT_TOKEN="$(vault token create -field token -policy=pki_int)"

# Create the TKS environment
cat  > certs/client-$CA_CLIENT/env-tls.sh << EOF
export VAULT_CLIENT_CERT=\$PWD/certs/client-$CA_CLIENT/$CA_CLIENT-cert.pem
export VAULT_CLIENT_KEY=\$PWD/certs/client-$CA_CLIENT/$CA_CLIENT-key.pem
export VAULT_CACERT=\$PWD/certs/client-$CA_CLIENT/ca_chain.pem
export VAULT_TOKEN=$VAULT_TOKEN
export VAULT_ADDR=https://$VAULT_SERVER_DOMAIN:8200
EOF
chmod -R a+r certs/client-$CA_CLIENT/

if [ "$INIT_AUTO_UNSEAL" == "yes" ]; then
  UNSEAL_SECRET=$RESULT_VAULT ./scripts/init_auto_unseal.sh &
fi
