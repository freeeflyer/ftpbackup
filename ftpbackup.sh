#!/bin/bash
CURLOPT="-s"
LOGFILE="/var/log/ftpbackup.log"
source ../etc/ftpbackup.ini
if [ -z $FTPHOST ]
then
    echo Missing config file ../etc/backup.ini
    exit 1
fi

DATE=$(date +%Y%m%d)
BACKUP_FAILED=
HOSTNAME=$(hostname -A)

function pipe2log()
{
   DATE=$(date --rfc-3339=second) 
   cat | sed "s#^#${DATE}: #" >> $LOGFILE
}

function do_backup_fs()
{
   dir=${1/\//} # remove leading "/"
   filename="${DATE}_${dir//\//_}.tgz"
   url="ftp://${FTPUSER}:${FTPPWD}@${FTPHOST}/${HOSTNAME/ /}/${filename}"
   echo "Saving /$dir to ${FTPHOST}" | pipe2log
   tar czf - /${dir} 2>/dev/null | curl $CURLOPT -T - ${url} | pipe2log
}

function test_backup_fs()
{
   dir=${1/\//} # remove leading "/"
   filename="$DATE_${dir//\/_}.tgz"
   url="ftp://${FTPUSER}:${FTPPWD}@${FTPHOST}/${HOSTNAME/ /}/${filename}"
   if ! curl ${url} | tar tzf - &> /dev/null; then
      BACKUP_FAILED="${BACKUP_FAILED} $dir"
      echo backup failed : ${FTPHOST}
   fi
}

function do_backup_mysql()
{
   base=${1}
   filename="${DATE}_mysql_${base}.sql.gz"
   url="ftp://${FTPUSER}:${FTPPWD}@${FTPHOST}/${HOSTNAME/ /}/${filename}"
   echo "Saving mysql base $base to ${FTPHOST}" | pipe2log
   mysqldump --defaults-file=${MYSQLPASSFILE} ${base} | gzip | curl $CURLOPT -T - ${url} | pipe2log
}

function do_backup_pg()
{
   base=${1}
   filename="${DATE}_pgsql_${base}.sql.gz"
   url="ftp://${FTPUSER}:${FTPPWD}@${FTPHOST}/${HOSTNAME/ /}/${filename}"
   echo "Saving pg base $base to ${FTPHOST}" | pipe2log
   sudo -u postgres pg_dump ${base} | gzip | curl $CURLOPT -T - ${url} | pipe2log
   echo "Status : ${PIPESTATUS[*]}" | pipe2log
}


#  Backup FS
if [[ ! -z $FS ]]
then
    for fs in $FS
    do
       do_backup_fs $fs
    done
fi

#  Backup PostgreSQL
if [[ ! -z $PGSQL ]]
then
    for pgbases in $PGSQL
    do
       do_backup_pg $pgbases
    done
fi

#  Backup MySQL
if [[ ! -z $MYSQL ]]
then
    for mysqlbases in $MYSQL
    do
       do_backup_mysql $mysqlbases
    done
fi


