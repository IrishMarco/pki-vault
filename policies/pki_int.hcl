# Allow user to create their own certificate
path "pki_int/issue/internal-dot-local" {
  capabilities = ["create", "update"]
}

