#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- logstash "$@"
fi

# Run as user "logstash" if the command is "logstash"
# allow the container to be started with `--user`
if [ "$1" = 'logstash' -a "$(id -u)" = '0' ]; then
	set -- gosu logstash tini -- "$@"
fi

exec "$@"

# #!/bin/bash
# set -e
# 
# # Add kibana as command if needed
# if [[ "$1" == -* ]]; then
# 	set -- kibana "$@"
# fi
# 
# # Run as user "kibana" if the command is "kibana"
# if [ "$1" = 'kibana' ]; then
# 	if [ "$ELASTICSEARCH_URL" ]; then
# 		sed -ri "s!^(\#\s*)?(elasticsearch\.url:).*!\2 '$ELASTICSEARCH_URL'!" /usr/share/kibana/config/kibana.yml
# 	fi
# 
# 	set -- gosu kibana tini -- "$@"
# fi
# 
# exec "$@"
