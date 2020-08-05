FROM docker.elastic.co/kibana/kibana:7.5.2

ENV SERVER_HOST="0.0.0.0"
ENV ELASTICSEARCH_HOSTS="https://192.168.99.77:9200"
ENV ELASTICSEARCH_USERNAME=elastic
ENV ELASTICSEARCH_PASSWORD=7I4ztgVfwiO1GOqbwDhS

COPY conf/kibana.yml /usr/share/kibana/config/
COPY conf/elasticsearch-ca.pem /usr/share/kibana/config/
