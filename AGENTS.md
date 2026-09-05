# AGENTS.md

Multi-arch Logstash image: pinned `FROM` over official `docker.elastic.co/logstash/logstash` with `logstash.conf` baked into the pipeline dir, deployed in the `elk` swarm stack.

## Commands

```bash
just build                                  # build jahrik/arm-logstash:latest
docker run --rm jahrik/arm-logstash:latest logstash -t -f /usr/share/logstash/pipeline/logstash.conf
just deploy                                 # swarm stack deploy (stack: elk)
```

## CI

`build.yml`: Test (build + `logstash -t` config check) on PR; Release (buildx amd64/arm64 push to Docker Hub) on merge to main. Needs `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` secrets. No armv7 — Elastic has no 32-bit images.

## Quirks

- Bump Logstash via the `FROM` tag; keep it on the same major as arm-elasticsearch.
- ES host comes from `${ELASTICSEARCH_HOST}` env substitution inside `logstash.conf`.
- Inputs: tcp/udp 5000 (arm-logspout's logstash route), beats 5044 (arm-filebeat).
- `playbook.yml`/`templates/` are the legacy host-config path (config was a host mount); the config is baked in now — kept as reference.
