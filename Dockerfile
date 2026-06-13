FROM docker.elastic.co/logstash/logstash:9.4.2

LABEL org.opencontainers.image.authors="jahrik@gmail.com"

COPY logstash.conf /usr/share/logstash/pipeline/logstash.conf
