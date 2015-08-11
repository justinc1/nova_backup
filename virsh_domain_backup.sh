#!/bin/bash

# Make backup of openstack instance, using virsh.
# VM will be shutoff.

#set -x
SRCDIR=`readlink -f $0`
SRCDIR=`dirname $SRCDIR`
source $SRCDIR/settings.sh
source $SRCDIR/local_settings.sh

DOM=$1
BACKUP_PREFIX=$2
DATE=`date +%Y%m%d-%H%M%S`

error_count="0"

echo "Backing up domain $DOM, to $BACKUP_PREFIX.$DATE files"
virsh dumpxml $DOM --security-info > $BACKUP_DEST/$BACKUP_PREFIX.$DATE.xml
sync
dom_disk_devs=`virsh domblklist $DOM | sed -e '/^Target.*Source$/d' -e '/^-*$/d' | awk '{print $1}'`
dom_blklist=`virsh domblklist $DOM | sed -e '/^Target.*Source$/d' -e '/^-*$/d'`
dom_disk_devs=`echo $dom_disk_devs`
# if domain in suspended state, backup the .save file
dom_save_file="/var/lib/libvirt/qemu/save/$DOM.save"
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
  echo "  $disk_dev -> $BACKUP_DEST/$BACKUP_PREFIX.$DATE.$disk_dev.qcow2"
  qemu-img convert -c -O qcow2  $disk $BACKUP_DEST/$BACKUP_PREFIX.$DATE.$disk_dev.qcow2
  ret=$?
  if [ "$ret" != "0" ]
  then
    echo "ERROR creating $BACKUP_DEST/$BACKUP_PREFIX.$DATE.$disk_dev.qcow2"
    error_count=$(( $error_count + 1 ))
    mv $BACKUP_DEST/$BACKUP_PREFIX.$DATE.$disk_dev.qcow2 $BACKUP_DEST/$BACKUP_PREFIX.$DATE.$disk_dev.qcow2.ERROR
  fi
done
# copy the .save file
if [ -f "$dom_save_file" ]
then
  echo "Backing up save $dom_save_file"
  /bin/cp "$dom_save_file" $BACKUP_DEST/$BACKUP_PREFIX.$DATE.save
fi
# leave VM in shutoff state
# virsh resume $DOM

if [ "$error_count" -gt 0 ]
then
  exit 2
fi
exit 0
