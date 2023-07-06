#!/bin/bash
set -o pipefail
set -o errexit
set -o nounset
#set -o xtrace

####################################################################################
export      ADMIN_PASSWORD="blahblah"
export OBSERVER_P_PASSWORD="blahblah"
export OBSERVER_S_PASSWORD="blahblah"

# INSTALL
yum -yq install epel-release vim bash-completion
yum -yq install nut usbutils

# UPS DRIVER
cat <<EOF > /etc/ups/ups.conf
[APC]
driver = usbhid-ups
port = auto
ignorelb
override.battery.charge.low = 99
EOF
cat /etc/ups/ups.conf && ls -alh /etc/ups/ups.conf

lsusb
udevadm control --reload-rules && udevadm trigger
systemctl enable nut-driver-enumerator --now
#usbhid-ups -u nut -DDD -a APC
#upsdrvctl -D -d start
#systemctl enable nut-driver@APC --now
sleep 2 && journalctl -u nut*

# NUT SERVER
cat << EOF > /etc/ups/upsd.users
[admin]
        password = ${ADMIN_PASSWORD}
        actions = set
        actions = fsd
        instcmds = all

[observer_p]
        password = ${OBSERVER_P_PASSWORD}
        upsmon primary

[observer_s]
        password = ${OBSERVER_S_PASSWORD}
        upsmon secondary
EOF
cat /etc/ups/upsd.users && ls -alh /etc/ups/upsd.users
sed -i "/^MODE=/ s/=.*/=netserver/" /etc/ups/nut.conf
echo "LISTEN 0.0.0.0" > /etc/ups/upsd.conf
#firewall-cmd --permanent --add-service=nut && firewall-cmd reload

# SELINUX SETUP
#yum install policycoreutils-python-utils audit
#ausearch -c 'upsd' --raw | audit2allow -M my-upsd
#semodule -X 300 -i my-upsd.pp
#systemctl restart nut-server && journalctl -f -u nut-server

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
FINALDELAY 20
MONITOR APC@localhost 1 observer_p ${OBSERVER_P_PASSWORD} primary
NOTIFYCMD "/usr/local/bin/nut_notify.sh"
NOTIFYFLAG ONLINE       EXEC+SYSLOG
NOTIFYFLAG ONBATT       EXEC+SYSLOG
NOTIFYFLAG LOWBATT      EXEC+SYSLOG
NOTIFYFLAG FSD          EXEC+SYSLOG
NOTIFYFLAG COMMOK       EXEC+SYSLOG
NOTIFYFLAG COMMBAD      EXEC+SYSLOG
NOTIFYFLAG SHUTDOWN     EXEC+SYSLOG
NOTIFYFLAG REPLBATT     EXEC+SYSLOG
NOTIFYFLAG NOCOMM       EXEC+SYSLOG
NOTIFYFLAG NOPARENT     EXEC+SYSLOG
EOF

systemctl enable nut.target --now
sleep 2 && journalctl -u nut*

#TEST
upscmd -u admin -p ${ADMIN_PASSWORD} -l APC
upscmd -u admin -p ${ADMIN_PASSWORD} APC test.panel.start 
