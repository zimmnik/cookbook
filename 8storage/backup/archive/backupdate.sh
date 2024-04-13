#!/bin/bash
#VERSION=220530

#UUID_EFI=""
#UUID_BOOT=""
UUID_EFI=1AB0-C0BC
UUID_BOOT=95c27112-0d18-4c65-8b73-61e24d7f9ee0
UUID_ROOT=319d39a0-97d8-4cc3-a6cc-464eafea09a3

UUID_BKP=1844529C44527D06

REMOTE_MOUNT=//fs/backup
REMOTE_HOST_PORT=(fs 445)

ROOT_STOR_MIN_FREE_GB=10
LOCAL_STOR_MIN_FREE_GB=75
REMOTE_STOR_MIN_FREE_GB=75

DATA_FOLDERS=(\
home/zorg/.ssh/ \
home/zorg/Desktop/ \
home/zorg/.mozilla/ \
home/zorg/.config/keepassxc/
)

#PASSPHRASE=""
PASSPHRASE=$(cat /etc/backup_passphrase)
#APPLY_UPDATES_COMMAND=""
APPLY_UPDATES_COMMAND="shutdown now"

#ANACRONTAB
#@daily 25 backup /usr/local/bin/cronic-jd /usr/local/bin/backupdate.sh
#FSTAB for USB DISK
#/dev/disk/by-uuid/90238d41-37fc-44e0-8f04-24b0dada9b68  /mnt/backup             btrfs   noauto,x-gvfs-hide              0 0

#---------------------------------------------------------------------------------------------
system_setup () {
  echo -en "\nSetup system ..."
  
  yum -y install btrfs-progs zstd netcat fwupd jq
  mkdir -v /mnt/backup || true
  mkdir -v /.sv || true

  btrfs subvolume snapshot -r / /.sv/previous_nightly || true
  btrfs subvolume snapshot -r / /.sv/latest_nightly || true
  btrfs subvolume snapshot -r / /.sv/previous_weekend || true
  btrfs subvolume snapshot -r / /.sv/latest_weekend || true

  echo " done"
}

#---------------------------------------------------------------------------------------------
system_check () {
  echo "Checking utilites..."
  command -v nc
  command -v tar
  command -v zstd
  command -v btrfs

  echo -en "\nChecking mountpoints... "
  test -d /mnt/backup/; if mountpoint /mnt/backup; then exit 1; fi

  echo -en "\nChecking source partitions existence..."
  if [[ -n "${UUID_EFI}" ]];  then test -b "/dev/disk/by-uuid/${UUID_EFI}";  echo -n " efi ";  fi
  if [[ -n "${UUID_BOOT}" ]]; then test -b "/dev/disk/by-uuid/${UUID_BOOT}"; echo -n " boot "; fi
  test -b "/dev/disk/by-uuid/${UUID_ROOT}";                                  echo " root "

  echo -en "\nChecking root free space..."
  local -r FREE_GB=$(($(cd / && stat -f --format="%a*%S" .)/1024**3))
  echo " ${FREE_GB}GB (MIN ${ROOT_STOR_MIN_FREE_GB}GB)"
  if [[ FREE_GB -lt ROOT_STOR_MIN_FREE_GB ]]; then exit 1; fi
}

#---------------------------------------------------------------------------------------------
storage_check () {
  case ${STOR} in
  local)
    echo -en "\nChecking ${STOR} storage availability..."
    test -b "/dev/disk/by-uuid/${UUID_BKP}"; echo " done"

    locking

    free_storage_check $LOCAL_STOR_MIN_FREE_GB
    writability_storage_check
    ;;
  remote)
    echo -en "\nChecking ${STOR} storage availability..."
    nc -z -v -w5 "${REMOTE_HOST_PORT[@]}"
    #ssh -Txak -o BatchMode=yes -o ConnectTimeout=5 fs 'exit 0'; echo " done"

    locking

    free_storage_check $REMOTE_STOR_MIN_FREE_GB
    writability_storage_check
    ;;
  esac
}

free_storage_check () {
  mount_stor
    local -r MIN_FREE_GB=$1
    echo -en "\nChecking ${STOR} storage free space..."
    local -r FREE_GB=$(($(stat -f --format="%a*%S" .)/1024**3))
    echo " ${FREE_GB}GB (MIN ${MIN_FREE_GB}GB)"
  umount_stor
  if [[ FREE_GB -lt MIN_FREE_GB ]]; then exit 1; fi
}

writability_storage_check () {
  mount_stor
    echo -en "\nChecking ${STOR} storage writability..."
    local -r UUID=$(uuidgen)
    echo "${UUID}" > testfile && sync
    local -r RESULT=$(cat testfile)
    if [[ "${UUID}" != "${RESULT}" ]]; then
      echo " fail" && umount_stor && exit 1
    else
      rm testfile && echo " done" && umount_stor
    fi
}

#---------------------------------------------------------------------------------------------
locking () {
  echo -en "\nLocking... "
  if [[ -f /tmp/backupdate.lock ]]; then
    echo "backup already running or crashed"
    return 1
  else
    touch /tmp/backupdate.lock
    echo "created /tmp/backupdate.lock"
  fi
}
unlocking () {
  echo -en "\nUnlocking... "
  rm -v /tmp/backupdate.lock || true
  sync
}

#---------------------------------------------------------------------------------------------
mount_stor () {
  case ${STOR} in
  local)
    mount "UUID=${UUID_BKP}"
    ;;
  remote)
    mount "${REMOTE_MOUNT}"
    ;;
  esac

  case ${TYPE} in
  system)
    cd "/mnt/backup/${HOSTNAME}/system/"
    ;;
  data)
    cd "/mnt/backup/${HOSTNAME}/data/"
    ;;
  esac
}
umount_stor () {
  cd /; sync && umount /mnt/backup
}

#---------------------------------------------------------------------------------------------
report () {
  mount_stor
    pwd
    tree -haD .
  umount_stor
}
script_backup () {
    cp -fv "$(readlink -f "${BASH_SOURCE[0]}")" ../..
    cp -fv /etc/systemd/system/backupdate.service ../..
    cp -fv /etc/systemd/system/backupdate.timer ../..
    cp -fv /etc/systemd/system/failure-mail@.service ../..
}
#---------------------------------------------------------------------------------------------
system_backup () {
  btrfs subvolume delete /.sv/previous_weekend
  btrfs subvolume snapshot -r /.sv/latest_weekend /.sv/previous_weekend
  btrfs subvolume delete /.sv/latest_weekend
  btrfs subvolume snapshot -r / /.sv/latest_weekend
  echo -e "\nBackup ${TYPE} to ${STOR} storage..."
  mount_stor
    cd latest/ && pwd

    if [[ -n "${PASSPHRASE}" ]]; then

      if [[ -n "${UUID_EFI}" ]]; then
        tar --selinux --one-file-system -cf - -C / boot/efi | zstd -z --quiet - | \
        gpg -c --pinentry-mode loopback --passphrase "${PASSPHRASE}" --compress-algo none -o "efi-${ID}.tar.zst.gpg"
        echo "efi-${ID}.tar.zst.gpg done"
      fi
      if [[ -n "${UUID_BOOT}" ]]; then
        tar --selinux --one-file-system -cf - -C / boot | zstd -z --quiet - | \
        gpg -c --pinentry-mode loopback --passphrase "${PASSPHRASE}" --compress-algo none -o "boot-${ID}.tar.zst.gpg"
        echo "boot-${ID}.tar.zst.gpg done"
      fi
      btrfs send --quiet /.sv/latest_weekend | zstd -z --quiet - | \
      gpg -c --pinentry-mode loopback --passphrase "${PASSPHRASE}" --compress-algo none -o "root-${ID}.btrfs.zst.gpg"
      echo "root-${ID}.tar.zst.gpg done"

    else

      if [[ -n "${UUID_EFI}" ]]; then
        tar --selinux --one-file-system -cf - -C / boot/efi | zstdmt -z --quiet -o "efi-${ID}.tar.zst"
        echo "efi-${ID}.tar.zst done"
      fi
      if [[ -n "${UUID_BOOT}" ]]; then
        tar --selinux --one-file-system -cf - -C / boot | zstdmt -z --quiet -o "boot-${ID}.tar.zst"
        echo "boot-${ID}.tar.zst done"
      fi
      btrfs send --quiet /.sv/latest_weekend | zstdmt -z --quiet -o "root-${ID}.btrfs.zst"
      echo "root-${ID}.tar.zst done"

    fi

    script_backup
    lsblk -o +label,fstype,uuid > "partition_layout-${ID}.txt"
  umount_stor
}

#---------------------------------------------------------------------------------------------
data_backup () {
  btrfs subvolume delete /.sv/previous_nightly
  btrfs subvolume snapshot -r /.sv/latest_nightly /.sv/previous_nightly
  btrfs subvolume delete /.sv/latest_nightly
  btrfs subvolume snapshot -r / /.sv/latest_nightly
  echo -e "\nBackup ${TYPE} to ${STOR} storage"
  mount_stor
    cd latest/ && pwd

    if [[ -n "${PASSPHRASE}" ]]; then
      tar --selinux -cf - -C /.sv/latest_nightly/ "${DATA_FOLDERS[@]}" | zstd -z --quiet - | \
      gpg -c --pinentry-mode loopback --passphrase "${PASSPHRASE}" --compress-algo none -o "data-${ID}.tar.zst.gpg"
      echo "data-${ID}.tar.zst.gpg done"
    else
      tar --selinux -cf - -C /.sv/latest_nightly/ "${DATA_FOLDERS[@]}" | zstd -z --quiet -o "data-${ID}.tar.zst" 
      echo "data-${ID}.tar.zst done"
    fi
    script_backup

  umount_stor
}

#---------------------------------------------------------------------------------------------
backup () {
  storage_check
  report
  ID="$(date '+%Y-%m-%d')-${SRANDOM}"
  case ${TYPE} in
  system)
    system_backup 
    ;;
  data)
    data_backup
    ;;
  esac
  report
  unlocking
}

#---------------------------------------------------------------------------------------------
backup_check_btrfs_zst () {
  if ! compgen -G "${PWD}/*.btrfs.zst" > /dev/null; then echo "Backups are absent! Exiting..."; exit 1; fi
  local FILE
  for FILE in *.btrfs.zst; do
    zstdmt -d -c "${FILE}" | btrfs receive --dump > /dev/null
    echo "${FILE} checked"
  done
}
backup_check_tar_zst () {
  if ! compgen -G "${PWD}/*.tar.zst" > /dev/null; then echo "Backups are absent! Exiting..."; exit 1; fi
  local FILE
  for FILE in *.tar.zst; do
    zstdmt -d -c "${FILE}" | tar xO > /dev/null
    echo "${FILE} checked"
  done
}
backup_check_btrfs_zst_gpg () {
  if ! compgen -G "${PWD}/*.btrfs.zst.gpg" > /dev/null; then echo "Backups are absent! Exiting..."; exit 1; fi
  local FILE
  for FILE in *.btrfs.zst.gpg; do
    gpg -d --quiet --pinentry-mode loopback --passphrase "${PASSPHRASE}" -o - "${FILE}" | zstdmt -d | btrfs receive --dump > /dev/null
    echo "${FILE} checked"
  done
}
backup_check_tar_zst_gpg () {
  if ! compgen -G "${PWD}/*.tar.zst.gpg" > /dev/null; then echo "Backups are absent! Exiting..."; exit 1; fi
  local FILE
  for FILE in *.tar.zst.gpg; do
    gpg -d --quiet --pinentry-mode loopback --passphrase "${PASSPHRASE}" -o - "${FILE}" | zstdmt -d | tar xO > /dev/null
    echo "${FILE} checked"
  done
}
backup_check () {
  #https://stackoverflow.com/questions/965053/extract-filename-and-extension-in-bash
  #https://stackoverflow.com/questions/9612090/how-to-loop-through-file-names-returned-by-find
  echo -e "\nChecking ${TYPE} backups on ${STOR} storage..."
  mount_stor
    cd latest/ && pwd
    if [[ -n "${PASSPHRASE}" ]]; then
      case ${TYPE} in
      system)
        if [[ -n "${UUID_EFI}" || -n "${UUID_BOOT}" ]]; then
          backup_check_tar_zst_gpg
        fi
        backup_check_btrfs_zst_gpg
        ;;
      data)
        backup_check_tar_zst_gpg
        ;;
      esac
    else
      case ${TYPE} in
      system)
        if [[ -n "${UUID_EFI}" || -n "${UUID_BOOT}" ]]; then
          backup_check_tar_zst
        fi
        backup_check_btrfs_zst
        ;;
      data)
        backup_check_tar_zst
        ;;
      esac
    fi
  umount_stor

  #case ${STOR} in
  #local)
  #  zstdmt -t --quiet "${FILE}"
  #  ;;
  #remote)
  #  # shellcheck disable=SC2029
  #  ssh fs "cd /stor/backup/${HOSTNAME}/${TYPE}/latest/ && zstdmt -t --quiet ${FILE}"
  #  ;;
  #esac
}

#---------------------------------------------------------------------------------------------
rotate () {
  storage_check
  report
  #backup_check
  mount_stor
    echo -e "\nRotating ${TYPE} backups on ${STOR} storage..."
    pwd
    rm -v -rf previous/
    mv -v latest/ previous/
    mkdir -v latest/
  umount_stor
  report
  unlocking
}

#---------------------------------------------------------------------------------------------
system_update () {
  fwupd_updates
  echo -n "Make repository index cache..."
  yum --quiet makecache && echo " done"
  install_updates enhancement
  install_updates bugfix
  install_updates security
}

fwupd_updates () {
  echo -n "Checking new fwupd updates..."
  UPDATES_COUNT=$(fwupdmgr get-updates --json | jq '.Devices[] .DeviceId' | wc -l)
  if [[ "$UPDATES_COUNT" -gt "0" ]]; then
    echo " found"
    exec 5>&1
    local -r LOG=$(fwupdmgr get-updates |& tee >(cat - >&5))
    printf "Subject: backupdate@$HOSTNAME\nFrom: root <blabla>\n\n${LOG}" | sendmail root
  else
    echo " nothing"
  fi
}

install_updates () {
    local -r UPDATES_TYPE=$1

    echo -n "Checking new dnf ${UPDATES_TYPE} updates..."

    set +o errexit
    yum "--${UPDATES_TYPE}" check-update &>/dev/null
    local -r RESULT="$?"
    set -o errexit

    case "$RESULT" in
    0)
      echo " nothing"
      ;;
    100)
      echo " found"
      exec 5>&1
      local -r LOG=$(yum "--${UPDATES_TYPE}" updateinfo info |& tee >(cat - >&5))
      yum --quiet --assumeyes --best "--${UPDATES_TYPE}" upgrade 2> >(grep -v "uavc:  op=load_policy lsm=selinux" 1>&2)

      if [[ "${UPDATES_TYPE}" = "security" ]]; then
        printf "Subject: backupdate@${HOSTNAME}\nFrom: root <blabla>\n\n${LOG}" | sendmail root
        if [[ -n "${APPLY_UPDATES_COMMAND}" ]]; then
          echo "We need apply security updates: ${APPLY_UPDATES_COMMAND}"
          ${APPLY_UPDATES_COMMAND}
        fi
      fi
      ;;
    *)
      exec 5>&1
      echo "yum returned exit code ${RESULT}" | tee >(cat - >&5) | sendmail root
      ;;
    esac
}

#---------------------------------------------------------------------------------------------
main () {
  set -o pipefail
  set -o errexit
  set -o nounset
  #set -o xtrace

  #system_setup
  system_check
  case $(date +%u) in
  1)
    STOR=local
    #----------------
    TYPE=data
    rotate
    backup
    #----------------
    TYPE=system
    rotate
    backup

    STOR=remote
    #----------------
    TYPE=data
    rotate
    backup
    #----------------
    TYPE=system
    rotate
    backup
    #----------------
    system_update
    ;;
  *)
    TYPE=data
    #----------------
    STOR=local
    backup
    #----------------
    STOR=remote
    backup
    ;;
  esac
}

main "$@"
