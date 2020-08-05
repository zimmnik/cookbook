#!/bin/bash
cat << 'EOF' > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
yum -y install elasticsearch-7.5.2-1

cd /usr/share/elasticsearch/
bin/elasticsearch-certutil ca --out elastic-stack-ca.p12 --pass ""
bin/elasticsearch-certutil cert --ca elastic-stack-ca.p12 --pass "" --out elastic-certificates.p12 --ca-pass "" --dns 192.168.99.77.nip.io
openssl pkcs12 -in elastic-certificates.p12 -cacerts -nokeys -out elasticsearch-ca.pem -password pass:
cp elastic-certificates.p12 /etc/elasticsearch/
chmod g+r /etc/elasticsearch/elastic-certificates.p12

cat << 'EOF' > /etc/elasticsearch/elasticsearch.yml
path.logs: /var/log/elasticsearch
network.host: [ 0 ]

xpack.security.enabled: true
xpack.security.http.ssl.enabled: true
xpack.security.http.ssl.keystore.path: elastic-certificates.p12
xpack.security.http.ssl.truststore.path: elastic-certificates.p12

discovery.type: single-node
EOF

mkdir -p /usr/share/elasticsearch/data
chown elasticsearch:elasticsearch /usr/share/elasticsearch/data
systemctl enable elasticsearch --now

bin/elasticsearch-setup-passwords auto -b -u "https://192.168.99.77.nip.io:9200" | tee passwords.txt

echo | openssl s_client -showcerts -servername 192.168.99.77 -connect 192.168.99.77:9200 2>/dev/null | openssl x509 -inform pem -noout -text | less

PASS=$(cat passwords.txt | grep "PASSWORD elastic" | cut -d " " -f4)
curl --cacert elasticsearch-ca.pem -u elastic:${PASS} -XGET https://192.168.99.77.nip.io:9200
