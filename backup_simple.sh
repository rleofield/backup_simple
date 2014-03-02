#! /bin/bash

# File 'backupSimple.sh'
# Autor: rleofield
# www.rleofield.de
# März 2014



# mit Kommentarzeichen die nötigen Zeilen für DRY_RUN ein-/ausblenden

# Test mit Kontrollausgabe, es wird nichts kopiert (siehe 'man rsync')
DRY_RUN=--dry-run
# kein Test, Daten werden kopiert
#DRY_RUN=



# Test auf root
# root wird benötigt, um auch Files von anderen Nutzern und die Systemfiles zu kopieren
[[ `id -u` == 0 ]] ||  {
	echo 'Um ein Backup anzufertigen, benötigt man root Rechte (sudo -s)'
	exit
}
# setze das heutige Datum und die Uhrzeit
TODAY=`date +%Y%m%d-%H%M`

# Logfile im vorher angelegten Logfolder
LOGFILE=/var/log/backup/bb_$TODAY.log
echo "Logfile: $LOGFILE"


# setze die Folder für das Backup, dise müssen auf der externen HD vorhanden sein, ohne slash am Ende
BACKUPHD=/media/hd500
BACKUPDIR=$BACKUPHD/backup
BACKUPBACKUPDIR=$BACKUPHD/backupbackup


# hier die Exclude-Files ablegen, um Folder in den Userverzeichnissen in /home vom backup auszuschliessen
EXCLUDEFILEDIR=/home/user/bin/backup
EXCLUDEFILEDIR=/home/richard/wrk/snippets2/gh/backupSimple


line="-------------------------"

echo "Backup externe HD: $BACKUPHD"
echo "Backup Verzeichnis: $BACKUPDIR"
echo "Backup Backup Verzeichnis: $BACKUPBACKUPDIR"

# test, ob der Backup Folder vorhanden ist, dise werden nicht automatisch angelegt
if [ ! -d $BACKUPDIR ]
then
	echo "Backup Folder '$BACKUPDIR' ist nicht vorhanden." | tee -a $LOGFILE
	echo "Ist die externe HD gemountet?"
	exit
fi
# test, ob der Backupbackup Folder vorhanden ist
if [ ! -d $BACKUPBACKUPDIR ]
then
	echo "Backup Backup Folder '$BACKUPBACKUPDIR' ist nicht vorhanden." | tee -a $LOGFILE
	echo "Ist die externe HD gemountet?"
	exit
fi


# schreibe Liste aller installierten Pakete auf die HD, wird danach vom Backup mit erfasst
# der Folder /etc/apt/packageslist muss vorhanden sein
echo "sichere Packageslist -> /etc/apt/packageslist/packages.list" | tee -a $LOGFILE
dpkg --get-selections | awk '!/deinstall|purge|hold/ {print $1}' > /etc/apt/packageslist/packages.list
echo "Packageslist gesichert" | tee -a $LOGFILE


# Funktion, die 'rsync' aufruft
function do_sourcefolder(){
	_sourcebase=$1
	_sourcefolder=$2

	# Test, ob 'exlude_*' existiert
	EXCLUDEFILE=$EXCLUDEFILEDIR/exclude_$_sourcefolder
	EXCLUDE=
	if [ -f $EXCLUDEFILE ]
	then
		EXCLUDE=$EXCLUDEFILE
		echo "Exclude-File: $EXCLUDE" | tee -a $LOGFILE
	fi
	slash=/
	FROM=$_sourcebase
	# wenn 'sourcebase' im Root liegt, dann darf 'sourcebase' nicht 'sourcefolder' voran gestellt werden
	if [ $FROM = $slash ]
	then
		echo "FROM ist /"
		FROM=/$_sourcefolder
	else
		FROM=$_sourcebase/$_sourcefolder
	fi

	BACKUP_TO=$BACKUPDIR$FROM
	BACKUP_BACKUP=$BACKUPBACKUPDIR$FROM

	if [ ! -d $BACKUP_TO ]
	then
          echo "mkdir -p $BACKUP_TO" | tee -a $LOGFILE	       
          mkdir -p $BACKUP_TO
	fi
	if [ ! -d $BACKUP_BACKUP ]
	then
          echo "mkdir -p $BACKUP_BACKUP" | tee -a $LOGFILE	       
	       mkdir -p $BACKUP_BACKUP
	fi

	echo "Backup-From   $FROM" | tee -a $LOGFILE
	echo "Backup-To     $BACKUP_TO" | tee -a $LOGFILE
	echo "Backup-Backup $BACKUP_BACKUP" | tee -a $LOGFILE

	OPTIONS=-rlptvgoSAXH

	# siehe 'man rsync'
	# -r, --recursive             recurse into directories
	# -l, --links                 copy symlinks as symlinks
	# -p, --perms                 preserve permissions
	# -t, --times                 preserve modification times
	# -v, --verbose               increase verbosity
	# -g, --group                 preserve group
	# -o, --owner                 preserve owner (super-user only)
	# -X, --xattrs                preserve extended attributes
	# -A, --acls                  preserve ACLs (implies -p)
	# -S, --sparse                handle sparse files efficiently
	# -H, --hard-links            preserve hard links

	echo "rsync $DRY_RUN  $OPTIONS  --delete --exclude-from=$EXCLUDE --backup --backup-dir=$BACKUP_BACKUP $FROM/ $BACKUP_TO/" | tee -a $LOGFILE
	#exit 0;
	rsync $DRY_RUN $OPTIONS --delete --exclude-from=$EXCLUDE --backup --backup-dir=$BACKUP_BACKUP $FROM/ $BACKUP_TO/ | tee -a $LOGFILE
	echo "Backup $FROM To $BACKUP_TO ok" | tee -a $LOGFILE
}

# Funktion, die die Liste der Sourcefolder abarbeitet und 'do_sourcefolder()' aufruft
function do_sourcefolders(){
	_sourcebase=$1
	_sourcefolders=$2

	echo $line | tee -a $LOGFILE
	cd $_sourcebase
	pwd
	echo "pwd `pwd`" | tee -a $LOGFILE
	echo $line | tee -a $LOGFILE
	echo "Sourcebase  $_sourcebase" | tee -a $LOGFILE
	echo "Backup-To     $BACKUP_TO" | tee -a $LOGFILE

	for _sourcefolder in $_sourcefolders
	do
		echo "Sourcebase  $_sourcebase" | tee -a $LOGFILE
		echo "Sourcefolder  $_sourcefolder" | tee -a $LOGFILE
		do_sourcefolder $_sourcebase $_sourcefolder

		echo $line | tee -a $LOGFILE
	done
}

# Hier geht es los



# Basis Folder des nachfolgenden Backup
SOURCEDIR=/

# Vorschlag, ohne /home
do_sourcefolders $SOURCEDIR "bin boot etc initrd lib lib32 lib64 opt root sbin selinux srv usr var"


# und noch der /home Folder:
SOURCEDIR=/home
do_sourcefolders $SOURCEDIR "user1 user2 user3 user4"

# usw.

# siehe: http://www.halfgaar.net/backing-up-unix
sync
sleep 2

echo $line | tee -a $LOGFILE
echo "Backup beendet"
echo $line | tee -a $LOGFILE
