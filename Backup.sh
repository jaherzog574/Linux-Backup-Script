#!/bin/bash

src="File Name"		# Enter the full path to the directory you wish to backup here.
dest="Destination Location"	# Enter the full path to the directory you wish to backup to here.
templog="Log Name"		# Enter the name of the log file that you want attched to your email.
an=MyBakp-$(date +%m-%d-%Y)_$(date +%H-%M-%S).tgz	# Enter the name you wish the archive to be called (the default option has the time/date in the name).
email="Your Email Address"	# Enter the email address you wish to send this to (note make shure sendmail is configured and running first).

touch $templog
echo "Computer name: $(hostname -A)" >> $templog
echo "Directory backed up: $src" >> $templog
echo "Started at $(date +%H:%M:%S) $(date +%m/%d/%Y)" >> $templog
echo "Archive name: $an" >> $templog
echo "Backup location: $dest" >> $templog
echo " " >> $templog
echo "Starting storage space on source partition: " $(df -h $src) >> $templog
echo " " >> $templog
echo "Starting storage space on destination partition: " $(df -h $bkp) >> $templog 
echo " " >> $templog
echo "########" >> $templog
echo " " >> $templog

tar -cvZf $dest$an $src >> $templog

echo " " >> $templog
echo "########" >> $templog
echo "Backup completed at: $(date +%H:%M:%S) $(date +%m/%d/%Y)" >> $templog
echo " " >> $templog
echo "Remaining storage space on source partition: " $(df -h $src) >> $templog
echo " " >> $templog 
echo "Remaining storage space on destination partition: " $(df -h $bkp) >> $templog 
echo " " >> $templog
echo " " >> $templog
echo "----- This is the end of the log file -----" >> $templog

echo "Backup on $(hostname -s) has completed at $(date +%H:%M:%S) on $(date +%m-%d-%Y), please check the attached file for details." | mailx -s "Backup complete on $(hostname -s)" -a $templog $email

rm $templog
