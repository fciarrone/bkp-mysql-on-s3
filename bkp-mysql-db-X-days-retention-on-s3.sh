#!/bin/bash

## Backup MySQL databases with X days retention on S3 storage
## Date 11/11/2019
## Created by Fabio Ciarrone

## User "dumpuser" must have permissions to perform backup routines

#---

#Database Username
db_user="dumpuser"
#Database password
db_pass="s3cuR3%P@ss"
#Database name
db_name="database"
#Database host
db_name_host="database_host"
#Local folder to create mysqldump
db_path_to_dump="/sql/database_bkp_folder"
#Mysqldump name
db_dumpfile="bkp-database"
#S3 storage destination
s3_bkp_bucket="s3://bucket/folder"
#Timestamp
timestamp=$(date +%Y-%m-%d_%Hh%Mm%Ss)
# How many days should we keep the backups on Amazon before deletion?
daystokeep="14"
# Delete old backups? Any files older than $daystokeep will be deleted on the bucket
# Don't use this option on buckets which you use for other purposes as well
# Default option     : 0
# Recommended option : 1
purgeoldbackups=1

#---

echo -e "Starting backup" $(date +%Y-%m-%d\ %H:%M:%S) "\n"

## Create New Dump

printf "Create dump \n"
mysqldump -v -h ${db_name_host} -u ${db_user} -p${db_pass} --databases ${db_name} --opt --events --routines --triggers --single-transaction > ${db_path_to_dump}/${db_dumpfile}_${timestamp}.sql 2> /tmp/dump.log

printf "Compress ${db_path_to_dump}/${db_dumpfile}_${timestamp}.sql \n"
gzip ${db_path_to_dump}/${db_dumpfile}_${timestamp}.sql

printf "Copy compressed ${db_dumpfile}_${timestamp}.sql.gz to S3 \n"
/usr/bin/s3cmd put ${db_path_to_dump}/${db_dumpfile}_${timestamp}.sql.gz ${s3_bkp_bucket}/${db_dumpfile}_${timestamp}.sql.gz > /tmp/s3cmd_put_log.out

printf "Remove ${db_dumpfile}_${timestamp}.sql.gz \n"
rm -v ${db_path_to_dump}/${db_dumpfile}_${timestamp}.sql.gz

# Deleting old files
if [[ "$purgeoldbackups" -eq "1" ]]
then
    echo -e "Removing old backup files..."
    olderThan=`date -d "$daystokeep days ago" +%s`

    /usr/bin/s3cmd --recursive ls $s3_bkp_bucket | while read -r line;
    do
        createDate=`echo $line|awk {'print $1" "$2'}`
        createDate=`date -d"$createDate" +%s`
        if [[ $createDate -lt $olderThan ]]
        then 
            fileName=`echo $line|awk {'print $4'}`
            echo -e "Removing old backup files $fileName"
            if [[ $fileName != "" ]]
            then
                /usr/bin/s3cmd del "$fileName"
            fi
        fi
    done;
fi

echo -e "Backup finished" $(date +%Y-%m-%d\ %H:%M:%S) "\n"

