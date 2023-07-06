#!/bin/bash
set -o pipefail
set -o errexit
set -o nounset
#set -o xtrace

####################################################################################
export MAILBOX="blahblah"
export MAILPASS="blahblah"
export SMTPHOST="[smtp.gmail.com]:587"

## INSTALL
yum -yq install postfix cyrus-sasl-plain

# ALIASES
sed -i '/^root:/s/^/#/g' /etc/aliases
echo "root:           ${MAILBOX}" > /etc/aliases
newaliases

# AUTH
echo "${SMTPHOST}    ${MAILBOX}:${MAILPASS}" > /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd

# MAPPING LOCAL BOX NAMES TO GLOBAL
echo "/.+/    ${MAILBOX}" >> /etc/postfix/generic
chmod 600 /etc/postfix/generic
postmap /etc/postfix/generic

# MAIN
cat <<EOF >> /etc/postfix/main.cf

relayhost = ${SMTPHOST}
smtp_generic_maps = regexp:/etc/postfix/generic
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_security_options =
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
EOF
systemctl enable postfix --now
#sleep 2 && journalctl -u postfix

# SENDMAIL TEST
export SUBJECT="SENDMAILTEST"
export MAILBODY="${HOSTNAME}"
#printf "Subject: ${SUBJECT}\n\n${MAILBODY}" | sendmail root
sendmail root <<-EOF
Subject: ${SUBJECT}

${MAILBODY}
EOF
sleep 2 && journalctl -u postfix

# MAILX TEST
yum -y install mailx
export SUBJECT="MAILXTEST"
export MAILBODY="${HOSTNAME}"
echo "${MAILBODY}" | mail -s "${SUBJECT}" root
sleep 2 && journalctl -u postfix
