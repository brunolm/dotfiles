function Fix-Ssh-Administrator-Authorized-Keys() {
    icacls C:\ProgramData\ssh\administrators_authorized_keys /remove "NT AUTHORITY\Authenticated Users"
    icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r
    get-acl C:\ProgramData\ssh\ssh_host_dsa_key | set-acl C:\ProgramData\ssh\administrators_authorized_keys
}
