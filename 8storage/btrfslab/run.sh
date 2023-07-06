#!/bin/bash
# shellcheck disable=SC2164

set -o xtrace
set -o pipefail
set -o nounset
set -o errexit

#-----------------------------------------------------------------------------------------

yum -yq install lsscsi vim mc less btrfsmaintenance

lsblk -o +label,fstype,uuid
mkfs.btrfs -L btrfslab -m raid1 -d raid10 /dev/vdb /dev/vdc /dev/vdd /dev/vde
#mkfs.btrfs -L btrfslab /dev/vdb
btrfs filesystem show

mount /dev/vde /mnt
btrfs filesystem usage /mnt/

cd /mnt
fallocate -l 1G 1.test
time sha256sum 1.test > 1.sum
time sha256sum -c 1.sum 
btrfs filesystem usage /mnt/

time dd if=/dev/urandom of=/dev/vdc bs=1024 seek=$((RANDOM%10)) count=1572864 conv=notrunc oflag=direct

btrfs_scrape_paths=("/" "/mnt")
for path in "${btrfs_scrape_paths[@]}"; do
  time btrfs scrub start -BR "${path}"
  echo done
done
