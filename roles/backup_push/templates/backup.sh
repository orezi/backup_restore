#!/bin/bash
#backup of important data
set -ex

TIME=`date +%b-%d-%y`            # get date to add to file name
FILENAME=server-config-backup-$TIME.tar.gz    # define backup name format.
SRCDIR=/etc                    #foler to backup.
DESDIR=/home/ubuntu/sysbackup    # destination of backup
DB={{db_to_backup}}
SQLUSERNAME={{sql_username}}
SQLPASSWORD={{sql_password}}
DB_BACKUP={{db_backup_name}}

#start backup of /etc folder
tar -cpzf $DESDIR/$FILENAME $SRCDIR #backup srcdir to desdir/filename

tar -xvzf $DESDIR/$FILENAME -C {{ansible_env.PWD}}

diff -r --no-dereference {{folder_to_backup}}/ {{ansible_env.PWD}}{{folder_to_backup}}/
OUT=$?
if [ $OUT -eq 0 ]; then 
  {{aws_path.stdout}} s3 mv $DESDIR/ s3://{{s3_website_domain}}/ --recursive #push desdir/filename to aws s3 bucket
  rm -rf $DESDIR/* {{ansible_env.PWD}}{{folder_to_backup}}/
  echo "success"
else
	echo "fail"
	exit 1
fi
######Finish backup of /etc folder#####


######Start backup of database#######
{{automysqlbackup_path.stdout}} /etc/default/automysqlbackup  #create sql dump of database

#define raw sql commands
Q1="CREATE DATABASE $DB_BACKUP;"
Q2="DROP DATABASE $DB_BACKUP;"
MYSQL="$(which mysql)" #get absolute path for mysql
DBCOMPARE="$(which mysqldbcompare)" #get absolute path for mysqldbcompare

BACKUP="$(ls /var/lib/automysqlbackup/daily/$DB/ -1t | head -1)"   #get the last modified daily backup file
gunzip "/var/lib/automysqlbackup/daily/$DB/${BACKUP}" #unzip the last modified backup file
$MYSQL -u $SQLUSERNAME -p"${SQLPASSWORD}" -e "${Q1}" #drop backup db if exists and recreate backup db

DUMP="$(ls /var/lib/automysqlbackup/daily/$DB/ -1t | head -1)" #get dump file

$MYSQL -u $SQLUSERNAME -p"${SQLPASSWORD}" $DB_BACKUP < /var/lib/automysqlbackup/daily/$DB/$DUMP #restore database

$DBCOMPARE --server1=${SQLUSERNAME}:${SQLPASSWORD}@127.0.0.1 $DB:$DB_BACKUP --run-all-tests > /home/ubuntu/results.log
COMPARE=$?
if [ $COMPARE -eq 0 ]; then 
	gzip /var/lib/automysqlbackup/daily/$DB/${DUMP}
  {{aws_path.stdout}} s3 mv /var/lib/automysqlbackup/daily/$DB/${DUMP}.gz s3://{{s3_website_domain}}/
  rm -rf /var/lib/automysqlbackup/*
  echo "success"
else
	echo "fail"
	exit 1
fi
$MYSQL -u $SQLUSERNAME -p"${SQLPASSWORD}" -e "${Q2}"
echo "finished script..."



