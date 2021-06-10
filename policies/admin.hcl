# Administrator privileges. Be carefull with this account
path "*" {
    capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}
