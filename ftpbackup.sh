#!/bin/bash
source ../etc/backup.ini
if [ -z $FTPHOST ]
then
    echo Missing config file ../etc/backup.ini
    exit 1
fi

DATE=$(date +%Y%m%d)
BACKUP_FAILED=
HOSTNAME=$(hostname -A)

function do_backup_fs()
{
   dir=${1/\//} # remove leading "/"
   filename="${DATE}_${dir//\//_}.tgz"
   url="ftp://${FTPUSER}:${FTPPWD}@${FTPHOST}/${HOSTNAME/ /}/${filename}"
   echo "Saving /$dir to $url"
   tar czf - /${dir} | curl -T - ${url}
}

function test_backup_fs()
{
   dir=${1/\//} # remove leading "/"
   filename="$DATE_${dir//\/_}.tgz"
   url="ftp://${FTPUSER}:${FTPPWD}@${FTPHOST}/${HOSTNAME/ /}/${filename}"
   if ! curl ${url} | tar tzf - &> /dev/null; then
      BACKUP_FAILED="${BACKUP_FAILED} $dir"
      echo backup failed : $url
   fi
}

function do_backup_mysql()
{
   base=${1}
   filename="${DATE}_mysql_${base}.sql.gz"
   url="ftp://${FTPUSER}:${FTPPWD}@${FTPHOST}/${HOSTNAME/ /}/${filename}"
   echo "Saving mysql base $base to $url"
   mysqldump --defaults-file=${MYSQLPASSFILE} ${base} | gzip | curl -T - ${url}
}

function do_backup_pg()
{
   base=${1}
   filename="${DATE}_pgsql_${base}.sql.gz"
   url="ftp://${FTPUSER}:${FTPPWD}@${FTPHOST}/${HOSTNAME/ /}/${filename}"
   echo "Saving pg base $base to $url"
   sudo -u postgres pg_dump ${base} | gzip | curl -sS -T - ${url}
   echo "Status : ${PIPESTATUS[*]}"
}


#  Backup FS
if [[ ! -z $FS ]]
then
    for fs in $FS
    do
       do_backup_fs $fs
    done
fi

if [[ ! -z $PGSQL ]]
then
    for pgbases in $PGSQL
    do
       do_backup_pg $pgbases
    done
fi

if [[ ! -z $MYSQL ]]
then
    for mysqlbases in $MYSQL
    do
       do_backup_mysql $mysqlbases
    done
fi


