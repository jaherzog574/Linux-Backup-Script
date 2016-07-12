#!/bin/bash
name=$1
source=$2
dest=$3
bkupLimt=${4-"5"}			 # Useful if you want to change the number of backups that are kept.
exclude=${5-"none"}      # Useful if you want to exclude a directory (sets the value to "none" if no value is given), specifying a wildcard DOES NOT WORK 
arname="$name-$(date +%m-%d-%Y)at$(date +%H-%M-%S).tar.gz"
tmpLog="/tmp/$name-tmpLog.rtf"
fulLog="/var/log/$name-fullLog.rtf"
fleLst="/tmp/$name-fileList.rtf"
svrIp="127.0.0.1" # leave at "127.0.0.1" if the backup is a local backup, otherwise change it to backup server's IP.
email="email@example.com"

# Pre-backup checks

#Clears the terminal and checks if root is running the script
clear
if [ $(whoami) != "root" ]
then
	echo "Script must be run as root!"	
	echo "Script was not run as root, backup aborted" | mailx -s "$(hostname -s): $name backup failed" @email
	exit 1
fi

#Delete old temporary log files (in case the last backup stopped suddenly), recreates the tmp log, file list, and full log (if not already existent) and puts 3 spaces in the full log (for better readibility).
logger "$(date +%m/%d/%Y) at $(date +%H:%M:%S) - starting $name backup..."
rm "$tmpLog" "$fleLst" >> /dev/null 2>&1
touch "$tmpLog" "$fleLst" "$fulLog"
echo "" >> "$fulLog"
echo "" >> "$fulLog"
echo "" >> "$fulLog"

#Checks if the server it will backup to is up (waits a maximum of 30 seconds between pings).
ping -c 3 -t 30 $svrIp > /dev/null 2>&1

# If the ping fails (server is down)
if [ $? -ne 0 ]
then
	echo "Backup server has not responded to 3 consecutive pings. Server is likely down. Stopping script and notifing administrator." >> "$tmpLog"
	logger "$(date +%m/%d/%Y) at $(date +%H-%M-%S)- $name Backup aborted, server ($svrIp) failed to respond to ping"
	( echo "WARNING: $name backup failed becouse the server at address $svrIp appears down or failed to ping from host $(hostname).";  echo "$name backup for $(date +%m-%d-%Y) at $(date +%H:%M:%S) has been aborted"; cat "$tmpLog" ) | mail -s "WARNING: $name backup failed" -A "$tmpLog" $email
	cat "$tmpLog" >> "$fulLog"
	rm "$tmpLog"
	exit 2
fi

echo "Backup server appears accessible, continuing with backup..." >> "$tmpLog"



#Checks if backup location exists creates one if needed
if [ ! -d "$dest" ]
then
	echo "Specified backup location doesn't exist, creating it" >> "$tmpLog"
	mkdir "$dest" >> "$tmpLog"
fi

#Creates "header" for the temp log file
echo "" >> "$tmpLog"
echo "" >> "$tmpLog"
echo "Backup name: $name" >> "$tmpLog"
echo "Computer name: $(hostname)" >> "$tmpLog"
echo "Started at: $(date +%H:%M:%S) on $(date +%m/%d/%Y)" >> "$tmpLog"
echo "Directory being backed up: $source/ " >> "$tmpLog"
echo "" >> "$tmpLog"
echo "Archive location: $dest/$arname" >> "$tmpLog"
echo "" >> "$tmpLog"
echo "File system status: " >> "$tmpLog"
df -h "$source" "$dest" >> "$tmpLog"
echo "" >> "$tmpLog"
echo "" >> "$tmpLog"





#Creates archive
echo "Starting $name backup at $(date +%m/%d/%Y) at $(date +%H:%M:%S), check attached fleLog.rtf for details." >> "$tmpLog"
logger "$(date +%m/%d/%Y) at $(date +%H:%M:%S) - $name backup has begun creating it's archive"

#Checks if there is a exclusion
if [ "$exclude" = "none" ]
then
	tar -cvzf "$dest/$arname" "$source/" >> "$fleLst" 2>&1
else
	tar -cvzf "$dest/$arname" "$source/" --exclude="$exclude" >> "$fleLst" 2>&1	
fi

#Sends an email if the tar command encontered a fatal error
if [ $? -ne 0 ]
then
	echo "" >> "$tmpLog"
	echo "WARNING: Tar exited with non-zero status, backup failed" >> "$tmpLog"
	( echo "WARNING: $name Backup failed on $(hostname -s) on $(date +%m/%d/%Y) at $(date +%H:%M:%S), please check the information below and the attached files for more details: "; echo ""; echo ""; cat "$tmpLog" ) | mail -s "$(hostname): $name backup failed" -A "$tmpLog" -A "$fleLst" $email
	logger "$(date +%m/%d/%Y) at $(date +%H:%M:%S) - $name backup failed (tar exited with non-zero status)."
	exit 3
fi

logger "$(date +%m/%d/%Y) at $(date +%H:%M:%S) - $name archive at has been created."





#Post-Backup checks

#Checks if archive is accessable
touch "$dest/$arname"

if [ $? -eq 0 ]
then
	echo "Archive can be touched, backup success." >> "$tmpLog"
fi



#Changes the archive permissions
echo "" >> "$tmpLog"
echo "Changing the file permissions of the backup archive..." >> "$tmpLog"
chmod -v 777 "$dest/$arname" >> "/dev/null" 2>&1

#Checks if the changing permissions was successful 
if [ $? -eq 0 ] 
then	
	echo "Permissions command completed successfully, desireable permissions should be set now:" >> "$tmpLog"
	ls -lh "$dest/$arname" >> "$tmpLog"
	
else
	echo "WARNING: chmod returned non-zero status, archive may have undesirable permissions." >> "$tmpLog"
fi




#Purges all but the last number of specified backups, displays output in easy to read form.
echo "" >> "$tmpLog"
echo "" >> "$tmpLog"
echo "" >> "$tmpLog"
echo "Destination directory before purge: " >> "$tmpLog"
cd "$dest/" >> "$tmpLog"
ls -h >> "$tmpLog"
logger "$(date +%m/%d/%Y) at $(date +%H:%M:%S) - purging all $name backups but the last $bkupLimt"
ls -tQ | tail -n+$((1+$bkupLimt)) | xargs rm

# Checks if the purge completed
if [ $? -eq 0 ]
then
	echo "" >> "$tmpLog"
	echo "Purge completed successfully" >> "$tmpLog"
	echo "" >> "$tmpLog"
	echo "Destination directory after purge (keep last $bkupLimt backups): " >> "$tmpLog"
	ls -h >> "$tmpLog"
else
	if [ "$(ls | wc -l)" -le $bkupLimt ]		# less then the specified number of backups (sutch as if this is the first backup).
	then
		echo "" >> "$tmpLog"
		echo "Purge is not nessesary as there are $bkupLimt or less backups in the backup location" >> "$tmpLog"
		echo "" >> "$tmpLog"
		echo "Current destination directory: " >> "$tmpLog"
		ls -lh >> "$tmpLog"
	else					# If failure is due to something else
		echo "" >> "$tmpLog"
		echo "WARNIING: Purge failed (unknown reason)" >> "$tmpLog"
		echo "" >> "$tmpLog"
		echo "Destination directory after failed purge: " >> "$tmpLog"
		ls -lh >> "$tmpLog" 
	fi
fi





#Lists information about this archive and other archives in the destination file system.
echo "" >> "$tmpLog"
echo "" >> "$tmpLog"
echo "File size of current backup archive: ">> "$tmpLog" 
du -shc "$dest/$arname" | tail -n 1 >> "$tmpLog"
echo "" >> "$tmpLog"
echo "Total of all file archives of this type: " >> "$tmpLog"
du -shc "$dest" | tail -n 1 >> "$tmpLog"

#Lists information about the file system (after backup).
echo "" >> "$tmpLog"
echo "" >> "$tmpLog"
echo "File system status: " >> "$tmpLog"
df -h "$source" "$dest" >> "$tmpLog"

#Creates "footer" for log file.
echo "" >> "$tmpLog"
echo "Finished at: $(date +%H:%M:%S) on $(date +%m/%d/%Y)" >> "$tmpLog" 
echo "Size of backup archive: $(du -shc "$dest/$arname" | tail -n 1)" >> "$tmpLog"
echo "Total size of all backups: $(du -shc "$dest/$arname" | tail -n 1)" >> "$tmpLog"
echo "" >> "$tmpLog" 
echo "--- This is the end of the log file ---" >> "$tmpLog"





#Sends email with temporary log file file list attached.
( echo "$name backup on $(hostname -s) has completed on $(date +%m/%d/%Y) at $(date +%H:%M:%S), please check the information below and the attached files for more details: "; echo ""; echo ""; cat "$tmpLog" ) | mail -s "$(hostname): $name backup complete" -A "$tmpLog" -A "$fleLst" $email

if [ $? -eq 0 ]
then
	echo "$(date) - Email to $email sent successfully" >> $tmpLog
else
	echo "$(date) - There was a problem sending an email to $email, email not sent" >> $tmpLog
fi




#Dumps the temp log into the full log before deleting the temp log and file list.
cat "$tmpLog" >> "$fulLog"
rm "$tmpLog" "$fleLst" >> /dev/null 2>&1
logger "$(date +%m/%d/%Y) at $(date +%H:%M:%S) - $name backup has completed."
exit 0
