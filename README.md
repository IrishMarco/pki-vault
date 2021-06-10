# PKI vault

This proof of concept creates a PKI server based on Vault. It configures automatically the root cert, the intermediate and allows any clients to create their own one.

First boot (see [scripts/init_vault_server.sh](https://github.com/IrishMarco/pki-vault/blob/main/scripts/init_vault_server.sh)):

- create the vault instance without TLS
- initialize it
- create root cert and intermediate
- create client cert to interact with vault
- unseal it if needed
- encrypt unseal keys and root token with gpg the keyvthe define [GPG_RECIPIENT](https://github.com/IrishMarco/pki-vault/blob/main/docker-compose.yml#L12)
- Vault is restarted and comes unseal (if requested)
           
Any other boot, the Vault comes up and is sealed,


The intend is to play with Vault and is not designed for production.

## Requirements
- Some knowledge on Vault and PKI
- Docker and docker-compose
- At least 1 GPG key loaded on [keyserver.ubuntu.com](https://keyserver.ubuntu.com)

## Installation

### Configuration
The project uses GPG to encrypt Vault's unseal keys and the initial root token.

Edit the [.env](https://github.com/IrishMarco/pki-vault/blob/main/.env) and add your GPG email address:
```bash
MYGPG=youremail@example.com
INIT_AUTO_UNSEAL=no
```

Starts the container:

```bash
docker-compose up -d
```

The vault is sealed at this stage if INIT_AUTO_UNSEAL=no. To unseal it (will ask for GPG password):
```bash
./scripts/unseal_tls.sh
```

## Create a certificate
A script allows to create a signed certificate from Vault and generate the pkcs12 needed by any browser

```bash
./scripts/client_create_cert.sh <domain_name>
```

The certificate are saved in the following directories:
```bash
certs/root               CA root private certificate/key
certs/public             CA and intermediate public certificate/key
certs/client-vault-init  Cert/key to be used by curl when creating new client cert
certs/server-certs       Vault private cert/key for TLS mode
```

It will create a certificate for the <domain_name>.internal.local
```bash
 > ll certs/client-<domain_name>/
total 36
drwxrwxr-x 2 user user 4096 May 31 01:26 ./
drwxrwxr-x 7 user user 4096 May 31 01:26 ../
-rw-rw-r-- 1 user user 1359 May 31 01:26 ca_chain.pem
-rw-rw-r-- 1 user user 1359 May 31 01:26 ca.pem
-rw-rw-r-- 1 user user 1440 May 31 01:26 <domain name>-cert.pem
-rw-rw-r-- 1 user user 6368 May 31 01:26 <domain name>.json
-rw-rw-r-- 1 user user 1679 May 31 01:26 <domain name>-key.pem
-rw------- 1 user user 2621 May 31 01:26 <domain name>.p12
```
## Using the UI
Since TLS is enabled, only client with a signed certificate & keys byt this Vault instance will be accepted.

Install the certificate in your favorite browser. [Firefox](https://support.securly.com/hc/en-us/articles/360008547993-How-to-Install-Securly-s-SSL-Certificate-in-Firefox-on-Windows)

## Restart from scratch
If you want to have a fresh start with the PKI server, use the following script
```bash
./scripts/clean.sh
```
Of course, all previous certificates are now useless since it is removing root and intermediates certificates.

## License
[MIT](https://github.com/IrishMarco/pki-vault/blob/main/LICENSE)

