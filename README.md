# arm-logstash

[![Build](https://github.com/jahrik/arm-logstash/actions/workflows/build.yml/badge.svg)](https://github.com/jahrik/arm-logstash/actions/workflows/build.yml)

Multi-arch [Logstash](https://www.elastic.co/logstash) image for the `elk` swarm stack. Originally a 2018 ARM port (Logstash 5.6 deb with hand-built libjffi); now a pinned layer over the official `docker.elastic.co/logstash/logstash` image with the pipeline baked in.

## Run

```bash
docker run -d -p 5000:5000 -p 5044:5044 -e ELASTICSEARCH_HOST=elasticsearch jahrik/arm-logstash:latest
```

Pipeline: tcp/udp on 5000 (logspout), beats on 5044 (filebeat), output to `${ELASTICSEARCH_HOST}:9200`.

## Deploy (swarm)

```bash
docker network create -d overlay elk   # once
just deploy                            # stack: elk
```

## Build

```bash
just build
just push
```

CI: PR builds + pipeline config validation; merge to main pushes multi-arch (amd64/arm64) to Docker Hub. No armv7: modern Logstash is 64-bit only.
