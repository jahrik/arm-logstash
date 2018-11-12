#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- logstash "$@"
fi

if [ -f /etc/logstash/logstash.yml ]; then
  ln -sf /etc/logstash/logstash.yml /usr/share/logstash/config/logstash.yml
fi
if [ -f /etc/logstash/log4j2.properties ]; then
  ln -sf /etc/logstash/log4j2.properties /usr/share/logstash/config/log4j2.properties
fi
if [ -f /etc/logstash/jvm.options ]; then
  ln -sf /etc/logstash/jvm.options /usr/share/logstash/config/jvm.options
fi

# Run as user "logstash" if the command is "logstash"
# allow the container to be started with `--user`
if [ "$1" = 'logstash' -a "$(id -u)" = '0' ]; then
	# Change the ownership of user-mutable directories to logstash
	for path in \
		/usr/share/logstash \
		/etc/logstash \
		/var/log/logstash \
	; do
		chown -R logstash:logstash "$path"
	done
	set -- gosu logstash tini -- "$@"
fi

exec "$@"
