#!/bin/bash
set -o pipefail
set -o errexit
set -o nounset
#set -o xtrace

####################################################################################
export            NUT_HOST="192.168.50.101"
export OBSERVER_S_PASSWORD="blahblah"

# INSTALL
yum -yq install epel-release vim bash-completion
yum -yq install nut-client

# NUT MONITOR
cat <<'EOF' >> /usr/local/bin/nut_notify.sh
export SUBJECT="$(date +%T) ${HOSTNAME} $*"
export MAILBODY="$*"
printf "Subject: ${SUBJECT}\n\n${MAILBODY}" | sendmail root
EOF
chmod +x /usr/local/bin/nut_notify.sh

cat << EOF > /etc/ups/upsmon.conf
MINSUPPLIES 1
SHUTDOWNCMD "shutdown now"
#POWERDOWNFLAG /etc/killpower
MONITOR APC@${NUT_HOST} 1 observer_s ${OBSERVER_S_PASSWORD} secondary
NOTIFYCMD "/usr/local/bin/nut_notify.sh"
NOTIFYFLAG SHUTDOWN     EXEC+SYSLOG
NOTIFYFLAG NOCOMM       EXEC+SYSLOG
EOF

systemctl enable nut-monitor --now
sleep 2 && journalctl -u nut*

#TEST
upscmd -u observer_s -p ${OBSERVER_S_PASSWORD} -l APC
upscmd -u observer_s -p ${OBSERVER_S_PASSWORD} APC test.panel.start 
