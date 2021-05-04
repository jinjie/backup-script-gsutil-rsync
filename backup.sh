#!/bin/bash

####################
# CONFIG VARIABLES #
####################

BACKUP_DESTINATION="/backup"
BACKUP_DIRS="/home"
DAYS_TO_KEEP="1"
MYSQL_USER="root"
MYSQL_PASS=""
MYSQL_DATABASES="" # LEAVE BLANK FOR ALL DATABASES
GS_BUCKET="gs://example.bucket.name" # BUCKET NAME

###############################
# DO NOT EDIT BELOW THIS LINE #
###############################

BACKUP_DESTINATION_DAY=${BACKUP_DESTINATION}/`date +%Y-%m-%d`
BACKUP_DESTINATION_DIRS=${BACKUP_DESTINATION_DAY}/dirs
BACKUP_DESTINATION_MYSQL=${BACKUP_DESTINATION_DAY}/mysql

mkdir -p $BACKUP_DESTINATION_DIRS
mkdir -p $BACKUP_DESTINATION_MYSQL

echo "Created ${BACKUP_DESTINATION_DAY} for backup destination"
echo "Backing up directories..."

for DIR in $BACKUP_DIRS
do
    echo "* ${DIR}..."
    DATA_FILENAME=${BACKUP_DESTINATION_DIRS}/`echo ${DIR} | sed -e 's/[^A-Za-z0-9._-]/_/g' | sed -e 's/^_//g'`.tar.gz
    tar czf $DATA_FILENAME $DIR
done

echo "Backing up mysql databases..."

if [ -z "$MYSQL_DATABASES" ]
then
    MYSQL_FILENAME=${BACKUP_DESTINATION_MYSQL}/all-databases.sql.gz
    mysqldump -u${MYSQL_USER} `[ ! -z "$MYSQL_PASS" ] && -p $MYSQL_PASS` --all-databases | gzip > $MYSQL_FILENAME
else
    for DATABASE in $MYSQL_DATABASES
    do
        MYSQL_FILENAME=${BACKUP_DESTINATION_MYSQL}/`echo $DATABASE | sed -e 's/[^A-Za-z0-9._-]/_/g'`.sql.gz
        echo $MYSQL_FILENAME
        echo "* ${DATABASE}..."
        mysqldump -u${MYSQL_USER} `[ ! -z "$MYSQL_PASS" ] && -p $MYSQL_PASS` $DATABASE | gzip > $MYSQL_FILENAME
    done
fi

echo "Deleting old backups (more than ${DAYS_TO_KEEP} days)..."
find $BACKUP_DESTINATION -mtime +${DAYS_TO_KEEP} -exec rm {} \;
find $BACKUP_DESTINATION -type d -empty -delete

echo "Rsync to Google Storage..."
gsutil -m rsync -rd $BACKUP_DESTINATION $GS_BUCKET

echo "Done"
