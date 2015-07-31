#!/bin/bash

# Usage $0 backup.conf
#set -x


function backup_one_volume() {
echo "Volume start at `date +%Y%m%d-%H%m%S`"
echo "volume_id $vol_id"
cinder_show=`cinder show $vol_id`
echo "$cinder_show"
if [ -z "$cinder_show" ]
then
  echo "ERROR volume $vol_id not found."
  continue
fi
# check volume status
vol_status=`echo "$cinder_show" | grep '^| *status *|' | awk '{print $4}'`
if [ "$vol_status" != "available" ]
then
  echo "WARNING vol_status is $vol_status, volume backup might be corrupted."
fi
# get LVM volume name
lvm_disk="/dev/cinder/volume-$vol_id"
if [ ! -e $lvm_disk ]
then
  echo "ERROR LVM disk $lvm_disk missing"
  continue
fi
# Simple dd, raw image. Could be a sparse file (dd_rescue), or compressed.
# No snapshots, there is no space anyway.
backup_file="$BACKUP_DEST/data/volume-$vol_id.$DATE.raw"
dd if=$lvm_disk of=$backup_file bs=4M
dd_ret=$?
if [ "$dd_ret" != "0" ]
then
  # input IO error, no disk space or ?
  # rename file to make this obvious
  echo "ERROR, rename output file $backup_file to $backup_file.ERROR"
  mv $backup_file $backup_file.ERROR
fi
echo "Volume done at `date +%Y%m%d-%H%m%S`"
}

# Keep at least N backups, and delete only backups older than X days
function backup_rotate() {
  echo '---------'
  backup_files_ok=` find $BACKUP_DEST/data/ -name 'volume-'$vol_id'\.[0-9]*-[0-9]*\.raw'`
  backup_files_err=` find $BACKUP_DEST/data/ -name 'volume-'$vol_id'\.[0-9]*-[0-9]*\.raw\.ERROR'`
  echo -e "backup_files_ok \n$backup_files_ok"
  echo -e "backup_files_err \n$backup_files_err"
  # keep at least N latest backups, from the _ok list only.
  backup_no_delete=`echo "$backup_files_ok" | sort | tail -n $ROTATION_MIN_COUNT`
  echo -e "backup_no_delete \n$backup_no_delete"
  # backups to delete
  backup_files_ok_delete=` find $BACKUP_DEST/data/ -name 'volume-'$vol_id'\.[0-9]*-[0-9]*\.raw' -mtime +$ROTATION_MIN_AGE`
  backup_files_err_delete=` find $BACKUP_DEST/data/ -name 'volume-'$vol_id'\.[0-9]*-[0-9]*\.raw\.ERROR' -mtime +$ROTATION_MIN_AGE`
  echo -e "backup_files_ok_delete \n$backup_files_ok_delete"
  echo -e "backup_files_err_delete \n$backup_files_err_delete"
  echo '---------'
  for ff in $backup_files_ok_delete $backup_files_err_delete
  do
    #file_ts=`echo $ff | sed -e "s|^$BACKUP_DEST/data/volume-$vol_id.||" -e "s|.raw$||" -e "s|.raw.ERROR$||"`
    echo "$backup_no_delete" | grep -q "$ff"
    grep_ret=$?
    if [ "$grep_ret" == "0" ]
    then
      echo "  keep $ff (ROTATION_MIN_COUNT)"
    else
      echo "  delete $ff"
      /bin/rm "$ff"
    fi
  done
}


function print_conf() {
echo '------------------------------------------'
echo "Conf from $BACKUP_CONF"
echo "NOVARC_FILE		$NOVARC_FILE"
echo "BACKUP_DEST 		$BACKUP_DEST"
echo "ROTATION_MIN_COUNT	$ROTATION_MIN_COUNT"
echo "ROTATION_MIN_AGE		$ROTATION_MIN_AGE [days]"
}


function main() {
echo "Start backup at `date +%Y%m%d-%H%m%S`"
print_conf

# source and test NOVARC_FILE
source $NOVARC_FILE
cinder list --all-tenants 1>/dev/null
if [ $? != "0" ]
then
  echo "ERROR invalid NOVARC_FILE $NOVARC_FILE?"
  return 1
fi

# show free disk
echo '------------------------------------------'
df -h $BACKUP_DEST
# test if NFS mounted
if [ ! -d "$BACKUP_DEST/zzz-magic-dirname-for-diskspace-check" ]
then
  echo "ERROR missing magic dir $BACKUP_DEST/zzz-magic-dirname-for-diskspace-check"
  echo "NFS not mounted?"
  return 1
fi

echo '------------------------------------------'
echo "Volumes to backup: $BACKUP_VOLUMES"
for vol_id in $BACKUP_VOLUMES
do
  echo '------------------------------------------'
  backup_one_volume 2>&1 | tee "$BACKUP_DEST/log/volume-$vol_id.$DATE.log"
  backup_rotate
done
# show free disk
echo '------------------------------------------'
df -h $BACKUP_DEST
echo '------------------------------------------'
echo "Stop backup at `date +%Y%m%d-%H%m%S`"
}


BACKUP_CONF="$1"
source $BACKUP_CONF || exit 1

DATE=`date +%Y%m%d-%H%M%S`
[ ! -d "$BACKUP_DEST/log" ] && mkdir "$BACKUP_DEST/log"
[ ! -d "$BACKUP_DEST/data" ] && mkdir "$BACKUP_DEST/data"
LOGFILE="$BACKUP_DEST/log/backup-$DATE.log"

main 1>>"$LOGFILE" 2>&1
