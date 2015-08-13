#!/bin/bash

# For each nova node, make backup of
#  /etc/ (is in /root/git-repos)
#  /var/lib/? - mysql DB, LDAP
#  modified nova files - symlinks in /root/git-repos/

# set -x

SRCDIR=`readlink -f $0`
SRCDIR=`dirname $SRCDIR`
source $SRCDIR/settings.sh
source $SRCDIR/local_settings.sh

DESTD=$HOST_BACKUP_DEST/`hostname`

RSYNC="/usr/bin/rsync -rav --delete"
TAR="/bin/tar"
MYSQLDUMP="/usr/bin/mysqldump"
MYSQL="/usr/bin/mysql"
SLAPCAT="/usr/sbin/slapcat"
MYSQL_EXCLUDE_DB="Database information_schema performance_schema"

function backup_git_repos() {
  echo "-------------------------------------------------------------"
  /bin/ls -la /root/git-repos/ > $DESTD/log/git-repos-list.$DATE.txt
  all_repos=`find /root/git-repos/ -type l -or -type d`
  all_repos=`echo $all_repos`
  for ff in $all_repos
  do
    if [ "$ff" == "/root/git-repos/" ]
    then
      continue
    fi
    gitdir=`readlink -f $ff`  # ff=/root/git-repos/ttrt -> gitdir=/home/user/ttrt-dir
    gitdir_dirname=`dirname $gitdir`  # ttrt-dir
    ff_basename=`basename $ff`  # ttrt
    echo "Backing up gitdir/ $gitdir -> $DESTD/day/git-repos/$ff_basename/"
    CMD="$RSYNC $gitdir/ $DESTD/day/git-repos/$ff_basename/"
    echo EXEC $CMD
    $CMD

    if [ $DAY_OF_WEEK == 7 ]
    then
      echo "Weekly backup $gitdir -> $DESTD/week/git-repos/$ff_basename.$DATE.tar.gz"
      # get file ttrt.DATE.tar.gz, with structure like ./ttrt-dir/file1 etc
      CMD="$TAR -czf $DESTD/week/git-repos/$ff_basename.$DATE.tar.gz -C $gitdir_dirname $gitdir"
      echo EXEC $CMD
      $CMD
    fi
  done
}


function backup_mysql() {
  echo "-------------------------------------------------------------"
  if [ -z "`which mysql`" ]
  then
    echo "INFO: mysql binary not found, so likely there is no DB to backup."
    return
  fi
  db_all=`$MYSQL -uroot -p$MYSQL_ROOT_PASS -e 'show databases;' | sed 's/asdfasdfasdf//'` # multiline
  #echo "DEBUG: db_all AA $db_all"
  for db_exc in $MYSQL_EXCLUDE_DB
  do
    db_all=`echo "$db_all" | sed "/^$db_exc$/d"`
  done
  db_all=`echo $db_all`  # to single line
  echo "DEBUG: db_all = $db_all"
  for db in $db_all
  do
    echo "Backing up mysql DB $db - > $DESTD/day/mysql/$db.$DATE.sql.gz"
    CMD="$MYSQLDUMP -uroot -p$MYSQL_ROOT_PASS $db | gzip -9 > $DESTD/day/mysql/$db.$DATE.sql.gz"
    echo EXEC $CMD
    /bin/bash -c "$CMD"
    if [ $DAY_OF_WEEK == 7 ]
    then
      echo "Weekly backup $DESTD/week/mysql/$db.$DATE.sql.gz"
      CMD="/bin/cp $DESTD/day/mysql/$db.$DATE.sql.gz $DESTD/week/mysql/$db.$DATE.sql.gz"
      echo EXEC $CMD
      $CMD
    fi
  done
}


function backup_ldap() {
  echo "-------------------------------------------------------------"
  if [ ! -d /etc/ldap/slapd.d/ ]
  then
    echo "INFO: no /etc/ldap/slapd.d dir, so no slapd here."
    return
  fi
  OUTDIR_DAY=$DESTD/day/ldap
  OUTDIR_WEEK=$DESTD/week/ldap
  [ ! -d $OUTDIR_DAY ] && mkdir $OUTDIR_DAY
  [ ! -d $OUTDIR_WEEK ] && mkdir $OUTDIR_WEEK

  # LDAP_BASE='dc=example,dc=com'
  ldap_postfix=`echo $LDAP_BASE | sed -e 's/dc=//g' -e 's/,/-/g'`
  # backup DIT data, DIT config and filesystem config (/etc/ldap/)
  DIT_DATA="$OUTDIR_DAY/`hostname`-$DATE-${ldap_postfix}.dit-data.ldif"
  DIT_CONFIG="$OUTDIR_DAY/`hostname`-$DATE-${ldap_postfix}.dit-config.ldif"
  FS_CONFIG="$OUTDIR_DAY/`hostname`-$DATE-${ldap_postfix}.fs-config.tar.gz"
  echo "  DIT_DATA=$DIT_DATA"
  echo "  DIT_CONFIG=$DIT_CONFIG"
  echo "  FS_CONFIG=$FS_CONFIG"

  CMD="$SLAPCAT -b $LDAP_BASE -l $DIT_DATA"
  echo EXEC $CMD
  $CMD
  CMD="$SLAPCAT -b cn=config -l $DIT_CONFIG"
  echo EXEC $CMD
  $CMD
  CMD="$TAR -czf $FS_CONFIG /etc/ldap/ /etc/ldapscripts"
  echo EXEC $CMD
  $CMD
}


function main() {
  echo "Backup start `date`"
  #[ -d $DESTD ] || mkdir $DESTD
  #[ -d $DESTD/log ] || mkdir $DESTD/log
  for subd in day week day/git-repos week/git-repos day/mysql week/mysql
  do
    [ -d $DESTD/$subd ] || mkdir $DESTD/$subd
  done

  backup_git_repos
  backup_mysql
  backup_ldap
  echo "Backup stop `date`"
}


DATE=`date +%Y%m%d-%H%M%S`
DAY_OF_WEEK=`date +%u`  # 7==sunday, weekly backup
## DAY_OF_WEEK=7
[ -d $DESTD ] || mkdir $DESTD
[ -d $DESTD/log ] || mkdir $DESTD/log

main 1>>$DESTD/log/host_backup.$DATE.log 2>&1

##
