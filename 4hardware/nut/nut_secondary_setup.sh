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
#POLLFAIL_LOG_THROTTLE_MAX 0
MONITOR APC@${NUT_HOST} 1 observer_s ${OBSERVER_S_PASSWORD} secondary
NOTIFYCMD "/usr/local/bin/nut_notify.sh"
NOTIFYFLAG SHUTDOWN     EXEC+SYSLOG
NOTIFYFLAG NOCOMM       EXEC+SYSLOG
EOF

mkdir -p /etc/systemd/system/nut-monitor.service.d
cat << EOF > /etc/systemd/system/nut-monitor.service.d/override.conf 
[Service]
ExecStartPre=
ExecStartPre=-/usr/bin/systemd-tmpfiles --create /usr/lib/tmpfiles.d/nut-common.conf

[Install]
WantedBy=
WantedBy=multi-user.target
EOF

systemctl enable nut-monitor --now
sleep 2 && journalctl -u nut*

#TEST
upscmd -u observer_s -p ${OBSERVER_S_PASSWORD} -l APC@${NUT_HOST}
upsc APC@${NUT_HOST}
