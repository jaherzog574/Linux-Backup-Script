#!/bin/bash

# Enter the name of the backup plan you want here.
name="Backup Name"

# Enter the full path to the directory you wish to backup here.
src="File Name"	

# Enter the full path to the directory you wish to backup to here.
dest="Destination location"

# Enter the name of the log file that you want attched to your email.
templog="log name"		

# Enter the name you wish the archive to be called (the default option has the time/date in the name).
an=MyBakp-$(date +%m-%d-%Y)_$(date +%H-%M-%S).tar.gz	

# Enter the email address you wish to send this to (note sendmail must be configured and running for this to work).
email="youremailaddress"

logger "Backup of $(name) started"
touch $templog
echo "Computer name: $(hostname -A)" >> $templog
echo "Directory backed up: $src" >> $templog
echo "Started at $(date +%H:%M:%S) $(date +%m/%d/%Y)" >> $templog
echo "Archive name: $an" >> $templog
echo "Backup location: $dest" >> $templog
echo "########" >> $templog
df -h $src $dest >> $templog
echo "################" >> $templog

tar -cvpzf $dest$an $src >> $templog

echo " " >> $templog
echo "############# Changing permissions ############" >> $templog
chmod -v 644 $dest$an >> $templog
echo "########" >> $templog
echo "Backup completed at: $(date +%H:%M:%S) $(date +%m/%d/%Y)" >> $templog
echo " " >> $templog
echo "Backup size of this archive: ">> $templog 
du -sh $dest$an >> $templog
echo "All archives of this type: " >> $templog
du -sh $dest >> $templog
echo "########" >> $templog
df -h $src $dest >> $templog
echo "########" >> $templog
echo "----- This is the end of the log file -----" >> $templog
logger "Done backing up $(name)"

echo "$(name) Backup on $(hostname -s) has completed at $(date +%H:%M:%S) on $(date +%m-%d-%Y), please check the attached file for details." | mailx -s "($name) backup complete on $(hostname -s)" -a $templog $email

rm $templog
