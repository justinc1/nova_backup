#!/bin/bash

NOVARC=/root/openrc
LOGIFLE=/var/lib/nova/justin-data/nova_instance_backup.log
VIRSH_DOMAIN_BACKUP_PATH=/root/justinc/virsh_domain_backup.sh
SSH_KEY=~/.ssh/nova_backup_user

if [ -z "$1" ]
then
  echo "Usage: $0 instance_uuid"
  exit 1
fi


function main() {
error_count=0
echo '------------------------------------'
echo "Start `date`"

source $NOVARC
nova_show=`nova show $INST_UUID`
# OS-EXT-SRV-ATTR:hypervisor_hostname or OS-EXT-SRV-ATTR:host ?
virsh_host=`echo "$nova_show" | grep 'OS-EXT-SRV-ATTR:hypervisor_hostname' | sed 's/|/ /g' | awk '{print $2}'`
virsh_dom=`echo "$nova_show" | grep 'OS-EXT-SRV-ATTR:instance_name' | sed 's/|/ /g' | awk '{print $2}'`
virsh_state=`echo "$nova_show" | grep 'OS-EXT-STS:vm_state' | sed 's/|/ /g' | awk '{print $2}'`

nova list --all-tenants | grep "$INST_UUID"
echo "nova instance_uuid $INST_UUID -> host $virsh_host, domain $virsh_dom"
if [ "$virsh_state" != "stopped" ]
then
  echo "ERROR virsh_state is not stopped ($virsh_state), shutdown VM first"
  error_count=$(( $error_count + 1 ))
fi

ssh -i $SSH_KEY root@$virsh_host $VIRSH_DOMAIN_BACKUP_PATH $virsh_dom
ssh_ret=$?
if [ "$ssh_ret" != "0" ]
then
  echo "ERROR ssh_ret $ssh_ret"
  error_count=$(( $error_count + 1 ))
fi
echo "Done `date`"
if [ "$error_count" != "0" ]
then
  return 2
fi
return 0
}

INST_UUID=$1
main 2>&1 | tee -a $LOGIFLE
if [[ "${PIPESTATUS[@]}" =~ [^0\ ] ]]
then
  exit 2
fi
exit 0
