# Allow the user interface
ui = true

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address          = "0.0.0.0:8200"

  # Enable TLS
  tls_disable      = "false"
  tls_require_and_verify_client_cert="true"

  # Define the certificates and key to use
  tls_cert_file      = "/vault/certs/server-certs/vault_cert.pem"
  tls_key_file       = "/vault/certs/server-certs/vault_key.pem"
  tls_client_ca_file = "/vault/certs/server-certs/ca.pem"
}

api_addr="https://127.0.0.1:8200"
