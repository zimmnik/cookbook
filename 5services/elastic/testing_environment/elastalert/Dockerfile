FROM python:3.6.9-buster

RUN apt -y update && apt -y install vim less mc openssl curl nmap
RUN pip install elastalert==0.2.1

WORKDIR /etc/elastalert
COPY elasticsearch-ca.pem .
COPY config.yaml .

COPY wrapper.sh /usr/local/bin/wrapper.sh
CMD ["wrapper.sh"]
