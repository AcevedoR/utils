# Centos welcome banner

How to put a welcome banner with server informations (RAM, CPU usage, Disk space...)

## How
- you may need something to modify someting in `/etc/ssh/sshd_config` but I don't remember what
- put `login-info.sh` in `/etc/profile.d/` (this is where you want to put login custom scripts)
- modify `login-info.sh` by changing the banner name, and the correct partition to use in `MAIN_DISK_PARTITION` variable
- `service sshd restart`
