# default config values for virsh_domain_backup.sh
BACKUP_DEST='/var/lib/nova/justin-data'

# local config values for nova_instance_backup.sh
# NOVARC=/root/openrc
LOGIFLE=/var/lib/nova/justin-data/nova_instance_backup.log
VIRSH_DOMAIN_BACKUP_PATH=/root/justinc/virsh_domain_backup.sh
# SSH_KEY=~/.ssh/nova_backup_user
# SSH_OPT=''

# local config for host_backup.sh
HOST_BACKUP_DEST='/var/lib/nova/justin-host-data'
MYSQL_ROOT_PASS=real_root_pass

# ldap backup
LDAP_BASE="dc=example,dc=com"
