#!/bin/bash

# Make backup of openstack instance, using virsh.
# VM will be shutoff.

#set -x

DOM=$1
DATE=`date +%Y%m%d-%H%M%S`
BACKUP_DEST='/var/lib/nova/justin-data'

error_count="0"

echo "Backing up domain $DOM"
virsh dumpxml $DOM --security-info > $BACKUP_DEST/$DOM-$DATE.xml
sync
dom_disk_devs=`virsh domblklist $DOM | sed -e '/^Target.*Source$/d' -e '/^-*$/d' | awk '{print $1}'`
dom_blklist=`virsh domblklist $DOM | sed -e '/^Target.*Source$/d' -e '/^-*$/d'`
dom_disk_devs=`echo $dom_disk_devs`
#
# Domain should be be already stopped in nova.
# Othervise, nova might notice VM in shutdown state, and than after virsh start, nova will issue shutdown.
virsh list | grep -q $DOM
if [ "$?" == "0" ]
then
  echo "ERROR domain $DOM is running, exit with error"
  exit 1
  # virsh shutdown $DOM --mode acpi
fi
# start disk backup/sync
for disk_dev in $dom_disk_devs
do
  disk=`echo "$dom_blklist" | grep $disk_dev | awk '{print $2}'`
  echo "Backing up disk $disk $disk_dev"
  echo "  $disk_dev -> $BACKUP_DEST/$DOM-$DATE.$disk_dev.qcow2"
  qemu-img convert -c -O qcow2  $disk $BACKUP_DEST/$DOM-$DATE.$disk_dev.qcow2
  ret=$?
  if [ "$ret" != "0" ]
  then
    echo "ERROR creating $BACKUP_DEST/$DOM-$DATE.$disk_dev.qcow2"
    error_count=$(( $error_count + 1 ))
    mv $BACKUP_DEST/$DOM-$DATE.$disk_dev.qcow2 $BACKUP_DEST/$DOM-$DATE.$disk_dev.qcow2.ERROR
  fi
done
# leave VM in shutoff state
# virsh resume $DOM

if [ "$error_count" -gt 0 ]
then
  exit 2
fi
exit 0
