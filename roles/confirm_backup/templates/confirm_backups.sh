#!/bin/bash
#backup of important data
set -ex

echo "starting script..."
TIME=`date +%b-%d-%y`            # get date to add to file name
FILENAME=backup-$TIME.tar.gz    # define backup name format.
SRCDIR=/etc                    #foler to backup.
DESDIR=/home/ubuntu/restore    # destination of backup

echo "downloading object"
{{aws_path.stdout}} s3 cp s3://{{s3_website_domain}}/$FILENAME $DESDIR

echo "extracting file"
tar -xvzf $DESDIR/$FILENAME -C {{ansible_env.PWD}}

echo "confirming backups"
diff -r --no-dereference {{folder_to_backup}}/ {{ansible_env.PWD}}{{folder_to_backup}}/
echo $? > {{ansible_env.PWD}}/tmp.txt

echo "cleaning system"
rm -rf $DESDIR {{ansible_env.PWD}}{{folder_to_backup}}/

echo "finished script..."
