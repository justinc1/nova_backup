# default config values for virsh_domain_backup.sh
BACKUP_DEST='/var/lib/nova/justin-data'

# default config values for nova_instance_backup.sh
NOVARC=/root/openrc
LOGIFLE=/var/lib/nova/justin-data/nova_instance_backup.log
VIRSH_DOMAIN_BACKUP_PATH=/root/justinc/virsh_domain_backup.sh
SSH_KEY=~/.ssh/nova_backup_user
SSH_OPT=''

# default config values for host_backup.sh
# backup files are in $BACKUP_DEST/host_backup/$HOSTNAME
HOST_BACKUP_DEST='/var/lib/nova/justin-host-data'
MYSQL_ROOT_PASS=root_pass

