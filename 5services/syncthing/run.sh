#!/bin/bash
# shellcheck disable=SC2164

#set -o xtrace
set -o pipefail
set -o nounset
set -o errexit

yum -y install syncthing
systemctl enable syncthing@root --now
#firewall-cmd --zone=public --add-service=syncthing --permanent
#firewall-cmd --reload
