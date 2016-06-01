#!/bin/bash
name="BackupName"
source="Source"
dest="Destination"
arname="($name)Bakp-$(date +%m-%d-%Y)at$(date +%H-%M-%S).tar"
tmpLog="/tmp/($name)TempLog.rtf"
fulLog="/var/log/($name)FullLog.rtf"
fleLst="/var/log/($name)FileList.rtf"
svrIp="127.0.0.1" # Set to "127.0.0.1" if local backup.
email="email address"

#Clears the terminal before starting
clear

#Removes any remaining temp logs or file logs (just in case the last script stopped unexpedidly).
rm "$tmpLog" > /dev/null
rm "$fleLst" > /dev/null

#Creates the temporary log, file list, and full log (if not already existent) and puts 3 spaces in the full log (for better readibility).
touch "$tmpLog"
touch "$fleLst"
touch "$fulLog"
echo "" >> "$fulLog"
echo "" >> "$fulLog"
echo "" >> "$fulLog"

#Checks if the server it will backup to is up or not. If it is not, it logs the failure to temp log, uses logger to log the failure, sends an email to administrator with the temp log attached, dumps temp log to full log, deletes the temp log and stops the script. If server appears up, the script continues and (should) create the backup.
ping -c 3 $svrIp > /dev/null 2>&1
# If the ping fails (server is down)
if [ $? -ne 0 ]; then
	echo "Backup server has not responded to any of the 3 pings, server is assumed down. Stopping script and emailing administrator of the failure!" >> "$tmpLog"
	logger "$name backup: Backup aborted (remote server not responding to 3 consecutive pings)."
	echo "Server $svrIp appears down from $(hostname -s) when $name backup was attempted on $(date +%m-%d-%Y) at $(date +%H:%M:%S), scheduled has been aborted!" | mail -s "Failed $name backup on $(hostname -s)" -A "$tmpLog" $email
	cat "$tmpLog" >> "$fulLog"
	rm "$tmpLog"
	exit 1
# If the ping succedes (server is up)
fi

echo "Backup server appears accessible, continuing with backup..." >> "$tmpLog"
logger "$name backup: Server at $svrIp appears up, begining backup for $(date +%m/%d/%Y) at $(date +%H:%M:%S)."


#Creates temp log "header"
echo "" >> "$tmpLog"
echo "Backup name: $name" >> "$tmpLog"
echo "Computer name: $(hostname)" >> "$tmpLog"
echo "Started on: $(date +%m/%d/%Y) at $(date +%H:%M:%S)" >> "$tmpLog"
echo "Directory being backed up: $source/" >> "$tmpLog"
echo "Archive location: $dest/$arname" >> "$tmpLog"

#Lists information about the file system
echo "" >> "$tmpLog"
echo "File system status: " >> "$tmpLog"
df -h "$source" "$dest" >> "$tmpLog"

#Displays an explaination to the log file and adds a space (readability).
echo "### If there is an error creating the archive, look at fleLog.rtf. ###" >> "$tmpLog"
echo "" >>"$tmpLog"

#Creates the backup archive and logs the backed up files to the file list
echo "### Backup on $(date +%m/%d/%Y) at $(date +%H:%M:%S) ###" >> "$fleLst"
logger "$name backup: has began creating it's archive ("$dest/$arname")."
tar -cvZf "$dest/$arname" "$source/" >> "$fleLst"
logger "$name backup: archive at "$dest/$arname" has been created."

#Changes the archive permissions and logs it to tmpLog
echo "### Changing the file permissions of the backup archive ###" >> "$tmpLog"
chmod -v 777 "$dest/$arname" >> "$tmpLog"

#Purges all but the last 5 backups, and displays output in easy to read form.
cd "$dest/" >> "$tmpLog"
echo "" >> "$tmpLog"
echo "Destination directory before purge: " >> "$tmpLog"
ls -lh >> "$tmpLog"
logger "$name backup: purging all but last 5 backups."
ls -tQ | tail -n+6 | xargs rm >> "$tmpLog"
echo "" >> "$tmpLog"
echo "Destination directory after purge (keep last 5 backups): " >> "$tmpLog"
ls -lh >> "$tmpLog"

#Lists information about this archive and other archives in the destination file system
echo "" >> "$tmpLog"
echo "Backup size of this backup archive: ">> "$tmpLog" 
du -sh "$dest/$arname" >> "$tmpLog"
echo "Total of all file archives of this type: " >> "$tmpLog"
du -sh "$dest" >> "$tmpLog"

#Lists information about the file system again (after backup), with space for readability.
echo "" >> "$tmpLog"
echo "File system status: " >> "$tmpLog"
df -h "$source" "$dest" >> "$tmpLog"

#Creates the log file footer (with a space for readability).
echo "" >> "$tmpLog"
echo "Finished on: $(date +%m/%d/%Y) at $(date +%H:%M:%S)" >> "$tmpLog" 
echo "--- This is the end of this backup ---" >> "$tmpLog"

#Sends email with temporary log file file list attached.
echo "$name Backup on $(hostname -s) has completed at $(date +%H:%M:%S) on $(date +%m-%d-%Y), please check the attached file for details." | mail -s "$name Backup complete on $(hostname -s)" -A "$tmpLog" -A "$fleLst" $email

#Dumps the temp log into the full log before deleting the temp log and file list.
cat "$tmpLog" >> "$fulLog"
rm "$tmpLog" >> /dev/null
rm "$fleLst" >> /dev/null
logger "$name backup: Backup for $(date +%m/%d/%Y) completed at $(date +%H:%M:%S), see log file at $fulLog for more details."
