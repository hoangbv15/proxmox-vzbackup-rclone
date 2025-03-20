#!/bin/bash
# ./vzbackup-rclone.sh rehydrate

############ /START CONFIG
dumpdir="/mnt/pve/backups/dump" # Set this to where your vzdump files are stored
rcremote="pcloud" # Set this to your rclone remote
# MAX_AGE=3 # This is the age in days to keep local backup copies. Local backups older than this are deleted.
############ /END CONFIG

_bdir="$dumpdir"
rcloneroot="$dumpdir/rclone"
timepath="$(date +%Y)/$(date +%m)/$(date +%d)"
rclonedir="$rcloneroot/$timepath"
remotevzdumpsdir="vzdumps"
remoteenvdir="env"
COMMAND=${1}
tarfile=${TARFILE}
exten=${tarfile#*.}
filename=${tarfile%.*.*}

if [[ ${COMMAND} == 'rehydrate' ]]; then
    rclone --config /root/.config/rclone/rclone.conf \
    --drive-chunk-size=32M copy $rcremote:/$remotevzdumpsdir $dumpdir \
    -v --stats=60s --transfers=16 --checkers=16
fi

# if [[ ${COMMAND} == 'job-start' ]]; then
#     echo "Deleting backups older than $MAX_AGE days."
#     find $dumpdir -type f -mtime +$MAX_AGE -exec /bin/rm -f {} \;
# fi


if [[ ${COMMAND} == 'env-backup' || ${COMMAND} == 'full-backup' ]]; then
    echo "Backing up main PVE configs"
    
    echo "Creating ramdisk to hold the backup files"
    mkdir -p /mnt/ramdisk
    mount -t tmpfs -o size=2G tmpfs /mnt/ramdisk
    
    _tdir=${TMP_DIR:-/mnt/ramdisk}
    _tdir=$(mktemp -d $_tdir/proxmox-XXXXXXXX)
    function clean_up {
        echo "Cleaning up"
        rm -rf $_tdir
    }
    trap clean_up EXIT
    _now=$(date +%Y-%m-%d.%H.%M.%S)
    _HOSTNAME=$(hostname -f)
    _filename1="$_tdir/proxmox_etc.$_now.tar"
    _filename2="$_tdir/proxmox_pve.$_now.tar"
    _filename3="$_tdir/proxmox_root.$_now.tar"
    _filename4="$_tdir/proxmox_gpuroms.$_now.tar"
    _filename_all="$_tdir/proxmox_backup_"$_HOSTNAME"_"$_now".tar.gz"

    echo "Tar files"
    # copy key system files
    tar --warning='no-file-ignored' -cPf "$_filename1" /etc/.
    tar --warning='no-file-ignored' -cPf "$_filename2" /var/lib/pve-cluster/.
    tar --warning='no-file-ignored' -cPf "$_filename3" /root/.
    tar --warning='no-file-ignored' -cPf "$_filename4" /usr/share/kvm/gpuroms/.

    echo "Compressing files"
    # archive the copied system files
    tar -cvzPf "$_filename_all" -C $_tdir/ .

    currentDir=${pwd}
    cd $_tdir
    echo "rcloning $_filename_all"
    rclone --config /root/.config/rclone/rclone.conf \
    --drive-chunk-size=32M move $_filename_all $rcremote:/$remoteenvdir \
    -v --stats=60s --transfers=16 --checkers=16 --multi-thread-streams=1
    cd $currentDir

    umount /mnt/ramdisk/
fi

if [[ ${COMMAND} == 'dump-backup' || ${COMMAND} == 'full-backup' || ${COMMAND} == 'job-end' ||  ${COMMAND} == 'job-abort' ]]; then
    # Upload vzdumps
    cd $dumpdir
    echo "rcloning vzdumps"

    rclone_upload () {
        for i in $1; do
            [ -f "$i" ] || break
            echo "rcloning $i"
            rclone --config /root/.config/rclone/rclone.conf \
                    --drive-chunk-size=32M copy $i $rcremote:/$remotevzdumpsdir \
                    -v --stats=60s --transfers=16 --checkers=16 --multi-thread-streams=1
        done
    }

    rclone_upload "*.vma.zst"
    rclone_upload "*.notes"
fi
