#!/usr/bin/env bash
####################################################
## Special thanks to pricetx who's backup.sh script is implemented in parts of this backup script and also
## TheUbuntuGuy who's offline-zfs-backup script is partly used in the WOL part of this script.
##
## Pricetx's Backup script:
## https://github.com/Pricetx/backup
##
## TheUbuntuGuy's offline-zfs-backup script:
## https://github.com/TheUbuntuGuy/offline-zfs-backup
####################################################

#####
# Remember when running this script it is recommended that you include --config <location of config file>.cfg
#####


###### Start of script ######



### Initial Variables ###

# Ensure that all possible binary paths are checked.
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

#Directory the script is in (for later use).
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

### LOAD IN CONFIG ###

# Default config location
CONFIG="${SCRIPTDIR}"/backup.cfg

if [ "$1" == "--config" ]; then
    # Get config from specified file
    CONFIG="$2"
elif [ $# != 0 ]; then
    # Invalid arguments
    echo "Usage: $0 [--config filename]"
	logger "the backup script failed (an invalid argument was provided)"
    exit
fi

# Load in config and set inital values.
CONFIG=$( readlink -f "${CONFIG}" )
source "${CONFIG}"
STARTTIME=$(date +%s)
BACKUPDATE=$(date -u +%Y-%m-%d_at_%H-%M)
DESTINATION="${REMOTEDIR}""$(hostname)"-"${BACKUPDATE}"
TMPSQLDUMP="${TEMPDIR}""tempMySqlDump.sql"

### Functions ###

# Provides the 'log' command to simultaneously log to
# STDOUT and the log file with a single command
# NOTE: Use "" rather than \n unless you want to have timestamp.
log() {
    echo -e "$(date -u +%Y-%m-%d@%H:%M:%S)" "$1" >> "${LOGFILE}"
    if [ "$2" != "noecho" ]; then
        echo -e "$1"
    fi
}

# Send email to administrator routine.
email() {
if [ "$SENDEMAIL" == "yes" ]; then	
	if [ "$1" == "success" ]; then
		echo "Backup completed successfuly on machine: $(hostname) in: ${DURATION} seconds." | mail -s "${SUCCESSFULEMAILSUBJECT}" "${TOEMAILADDRESS}"
		log "Backup success email sent to "${TOEMAILADDRESS}"."
	else	# If backup failed
		echo "Backup failed on machine: $(hostname) for the beacause: ${1}" | mail -s "${FAILUREEMAILSUBJECT}" "${TOEMAILADDRESS}"
		log "Backup failure email sent to "${TOEMAILADDRESS}"."
	fi
else # SENDEMAIL is false
	log "Email will not be sent (SENDEMAIL is set to false)"
fi
}


log "Backup script has started."
logger "The backup script has started"


# Defaults WOL command to etherwake.
log "Machine will default to using etherwake for WOL."; log ""
WOL="etherwake"



#########################
### Pre-flight Checks ###
#########################

# This section checks for all of the binaries used in the backup.
log "Starting binary check..."
BINARIES=( cat cd command date dirname echo find openssl pwd readlink rsync ssh tar sync etherwake mail logger)

# Iterate over the list of binaries, and if one isn't found, abort.
for BINARY in "${BINARIES[@]}"; do
    if [ ! "$(command -v "$BINARY")" ]; then
        log "Binary $BINARY not found, evaluating..."
		
		# Different versions of etherwake use a different name in order to run.
		if [ "$BINARY" == "etherwake" ]; then
			log "Binary appears to be etherwake"
			log "Checking if command ether-wake works... "
			
			# Sets the WOL value to "ether-wake if that is the appropreate command for the system".
			if [ "$(command -v "ether-wake")" ]; then
				WOL="ether-wake"
				log "ether-wake command exists, script will use that for WOL instead"
				# Continues on to check the next binary...
			
			# If the etherwake nor ether-wake works (neither package is installed).
			else
				log "ether-wake command does not exist."
				log "Neither ether-wake nor etherwake is installed. please install this package and try again."
				email "nither ether-wake nor etherwake is installed"
				logger "the backup script failed (neither ether-wake nor etherwake is installed this system)"
				exit
			fi
			
		else
			# Normal output if package is not installed.
			log "$BINARY is not installed. Install it and try again"
			email "$BINARY is not installed"
			logger "the backup script failed ($BINARY is not installed)"
			exit
		fi
    fi
done

log "Binary check complete, all required programs are installed."; log ""

# Wake up backup server (3 times beacause I don't trust WOL).
log "Waking up backup server..."
$($WOL -i eth0 $REMOTEMAC)
$($WOL -i eth0 $REMOTEMAC)
$($WOL -i eth0 $REMOTEMAC)
log "3 WOL packets sent to remote server, script will wait for the server to come up..."; log ""

# Give the server some time to boot.
sleep 5		#DEBUGGING: change back to 120 (or when not using calling script.)
log "Remote server should be up by now, trying to login to it over SSH..."

# Tries to login over SSH, logs and stops if the login fails.
if [ ! "$(ssh -oBatchMode=yes -p "${REMOTEPORT}" "${REMOTEUSER}"@"${REMOTESERVER}" echo test)" ]; then
    log "Failed to login to ${REMOTEUSER}@${REMOTESERVER}"
    log "Make sure that your public key is in their authorized_keys"
    email "SSH login failed"
    logger "the backup script failed (SSH login to remote server failed)"
    exit
fi

log "SSH login successful, remote server now up."

####################
### MYSQL BACKUP ###
####################
# If the MySQLDump command doesn't exist or user doesn't want to backup MySQL.
if [ ! command -v mysqldump ] || [ "$MYSQLUSERNAME" == "" ]; then
    log "MySQLDump command not found, or user has indicated that they do NOT want to backup MySQL."
	log "Script will continue but MySQL databases will NOT be backed up."

# If user does want MySQL backup, do so.
else
	###############
	## MySQLDump ##
	###############
	log "Executing MySQLDump..."
	logger "Backup script is executing MySQLDump..."
	mkdir "${TEMPDIR}" 2>/dev/null
	$(mysqldump -u ${MYSQLUSERNAME} -p${MYSQLPASSWORD} --all-databases --add-locks > "${TMPSQLDUMP}")
	BACKUP+=("${TMPSQLDUMP}")
	sync
	logger "MySQLDump complete!"
	log "MySQLDump Complete!"	
fi 

log ""

##################################
### Prepares the rsync Command ###
##################################
# Default rsync command (Partal, the last part of the command is appended after the exclusions are added )
log "Creating rsync command..."
RSYNCCMD="rsync -aqz --relative "

# Specifies any exclsions that are specified in the rsync command
if [ "${EXCLUDE[@]}" != "" ]; then
	log "Config file specifies files to be excluded, these will be removed from the backup."
	# Add exclusions to front of command
	for i in "${EXCLUDE[@]}"; do
		echo " --exclude $i" >> "${RSYNCCMD}"
	done
# Logs if there are no exclusions.
else
	log "No exclusions where specified in the config, all files in the source directory(s) will be backed up."
fi

RSYNCCMD=""${RSYNCCMD}""${BACKUP[*]}" -e ssh -p ${REMOTEPORT} ${REMOTEUSER}@${REMOTESERVER}:"${DESTINATION}""
log ""


###############################################
####### Creating the destination folder #######
###############################################
# Creates folder on remote server to contain the backup.
log "Creating folder with current date and time on remote server..."
if ! ssh -p "${REMOTEPORT}" "${REMOTEUSER}"@"${REMOTESERVER}" mkdir "${DESTINATION}" ; then
	# Logs if this action failed.
	log "Failed to create ${REMOTEDIR} on ${REMOTESERVER}"
	log "Backup cannot continue, admin will be emailed and script will stop..."; log ""
	email "remote directory could not be created to hold the uncompressed backup"
	logger "the backup script failed (remote directory could not be created to hold the uncompressed backup)"
	exit
fi

# Varifies that backup directory has been created.
log "Remote directory appears to have been created at ${REMOTEDIR} varifying that the folder exists..." 
sleep 0.25
# If the backup directory was NOT created, script logs the error and exits.
if ! ssh -p "${REMOTEPORT}" "${REMOTEUSER}"@"${REMOTESERVER}" test -d "${REMOTEDIR}" ; then
	log "${REMOTEDIR} was not created"
	log "Backup cannot continue, notifying admin and stopping script..."; log ""
	email "remote directory could not be created to hold the backup"
	logger "the backup script failed (remote directory could not be created)"
	exit
fi

log "Backup directory for backup has been created on remote server."


# Flushes the HDD of the local and remote server before begining rsync.
log "Begining rsync to remote server..."
logger "the backup script will now begin to rsync files over to the remote server"
sync
sleep 0.5 

###########################
### Running the Backup ####
###########################
# Run rsync, stops the script if the command fails.
if $RSYNCCMD 2>/dev/null ; then 
	log "rsync failed!"
	log "Script cannot continue, an email will be sent to admin and script will exit"
	logger "rsync command to remote server failed, the backup has failed, and the backup script will exit"
	email "rsync command failed, this is a fatal error the backup has failed and cannot continue"
	exit
fi

# Flushes HDD on local and remote machine.
sync
ssh -p "${REMOTEPORT}" "${REMOTEUSER}"@"${REMOTESERVER}" sync 
sleep 1

# Checks if rsync transfered ANY files over to the remote server.
log "rsync completed successfully, checking if remote directory contains any files..."
logger "the backup script has finished rsyncing the files over to the remote server."

if ssh -p "${REMOTEPORT}" "${REMOTEUSER}"@"${REMOTESERVER}" test -e "${DESTINATION}${BACKUP[1]}" ; then
	log "Success! rsync has transfered at least one file to the remote server"
	else
	log "rsync command completed successfully, but it did NOT copy any files to the remote server."
	log "This is a fatal error and the script must exit"
	logger "rsync command executed successfully, but failed to copy any files to the remote server, (this is a fatal error and script will now exit)"
	email "rsync command executed successfully, but failed to copy any files to the remote server, (this is a fatal error and the script will now exit)"
	exit
fi

log ""


#TODO: Verify checksums of backed up files.




############################
### Deleting old backups ###
############################

# Deletes the old MySQLDump file.
if [ -e "${TMPSQLDUMP}" ]; then
	log "Securely deleting old MySQLDump file (this may take awhile)..."
	shred -fuzn 5 "${TMPSQLDUMP}"
	log "Temporary MySQLDump has been securely deleted."
else
	log "Temporary MySQLDump file does not exist, deletion is not nessessary."
fi

log ""

# Delete all but last X number of backups.
#TODO: make the number of backups to hold customizable in the config (also change the logging and emails use the specified number of backups).
log "Attempting to delete all but the last 5 backups..."
if ! ssh -p "${REMOTEPORT}" "${REMOTEUSER}"@"${REMOTESERVER}" "ls -tr | head -n -5 | xargs rm -r" ; then
	log "Failed to delete all but the last 5 backups, backup script will continue, however you may have to delete these manuallly."
	email "backup script completed, however it was unable to delete the last 5 backups. This may occor if there are less then 5 backups being stored."
# Logs if the old backups where able to be deleted.
else
	log "All but last 5 backups have been securely deleted."
fi

# Flushes HDD buffers on local and remote server.
sync
ssh -p "${REMOTEPORT}" "${REMOTEUSER}"@"${REMOTESERVER}" sync
sleep 0.25
log ""

##########################
### Encryptiing Backup ###
##########################
# Makes an archive if user wants an archive or encryption (or has specified that they want bolth).
if [ $CREATEARCHIVE == "yes" ] || [ $BACKUPPASS != "" ]; then
	log "User wants compression/encryption, compressing backup on remote server..."
	# Runs tar command on remote server uses the pigz program to compress using multiple cores.
	ssh -p "${REMOTEPORT}" "${REMOTEUSER}"@"${REMOTESERVER}" "tar -zc --use-compress-program=pigz -f ${REMOTEDIR}.tgz ${DESTINATION}"
	# Securely deletes uncompressed backup on remote server.
	log "Compression complete. Securely deleting uncompressed backup..."
	ssh -p "${REMOTEPORT}" "${REMOTEUSER}"@"${REMOTESERVER}" "shred -fuzn 5 ${DESTINATION}"
	log "Secure deletion complete."
	log ""
fi

# Encrypts the archive on the remote server 
if [ $BACKUPPASS != "" ]; then
	log "User wants archive to be encrypted, applying encryption to archive on remote server..."
	"openssl enc -aes256 -in ${DESTINATION}.tgz -out ${DESTINATION}.enc -pass pass:${BACKUPPASS} -md sha1"
	# Securely deletes unencrypted archive on remote server.
	log "Encryption complete. Securely deleting unencrypted archive..."
	ssh -p "${REMOTEPORT}" "${REMOTEUSER}"@"${REMOTESERVER}" "shred -fuzn 5 ${DESTINATION}.enc"	
	log "Secure deletion complete."
	log ""
fi


##################################
### Emailing Admin and Exiting ###
##################################
# Flushes HDD buffers on local and remote server one last time.
sync
ssh -p "${REMOTEPORT}" "${REMOTEUSER}"@"${REMOTESERVER}" sync
sleep 0.25
# Gets the time that backup completed and figures out how long it took before sending email to admin.
ENDTIME=$(date +%s)
DURATION=$((ENDTIME - STARTTIME))
log "Backup completed in ${DURATION} seconds."
email "success"	
logger "the backup script has completed the backup successfuly and completed all post-backup tasks"
log "Backup complete, admin notified of completion and backup will now exit."
# Adds several lines to the bottom of the log file in order to reduce confusion.
log ""
log ""
log ""
exit
