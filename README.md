# Basic Linux Backup Script
A simple BASH script that that does backups of a specified directory, purges the older backups, and sends the user an email when complete.

It is important that you specify the following aguments (in order) when you call this script:
  - Backup name
  - Soruce Location
  - Destination Location
  - (optional) Backup limit (number of backups you wish to keep)
  - (optional) Exclusions (files/folders you wish to not include in the backup)

This script has been tested on Ubuntu Server 14.04 LTS and partually works on CentOS 6.5 (just change all the "-A"s on the mailx lines to "-a") as there is a slight difference between the current version of Mailx on CentOS and the one on Ubuntu. While it hasn't been varified, this script is expected to work on other (espessually Debian-based) Linux distrobutions as well (though it's best to use caution if this situation applies to you).

If you wish to automate this script, then make sure that the script has execute permissions, and is put in a reasonable location (I recommend putting it in the /sbin directory, but other locations work fine aswell). Modify the crontab to your liking making sure to include the nessessary arguments (I recommned setting the script to backup a small directory in a few minutes into the future to varify the script works properally before telling it to backup any real data).

Keep in mind that this is one of the first scripts that I've written. For this reason the script is far from perfect and is therefore not intended to be used in a production envirnment (Though this script is capable of doing so, it is not recommended).
