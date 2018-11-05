FROM arm32v7/openjdk:8-jdk

# Add logstash user and group first to make sure their IDs get assigned consistently
RUN groupadd -r logstash && useradd -r -m -g logstash logstash

# Dependencies
RUN apt-get update && apt-get install -y \
  --no-install-recommends \
  apt-transport-https \
  ca-certificates \
  build-essential \
  texinfo \
  libzmq5 \
  wget \
  vim \
  git \
  ant
RUN rm -rf /var/lib/apt/lists/*

# the "ffi-rzmq-core" gem is very picky about where it looks for libzmq.so
RUN mkdir -p /usr/local/lib \
	&& ln -s /usr/lib/*/libzmq.so.3 /usr/local/lib/libzmq.so

# gosu
# grab gosu for easy step-down from root
RUN set -eux; \
	apt-get update; \
	apt-get install -y gosu; \
	rm -rf /var/lib/apt/lists/*; \
# verify that the binary works
	gosu nobody true

# Tini
# For signal processing and zombie killing
ENV TINI_VERSION v0.18.0
ENV ARCH armhf
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${ARCH} /usr/local/bin/tini
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${ARCH}.asc /usr/local/bin/tini.asc
RUN gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7
RUN gpg --verify /usr/local/bin/tini.asc
RUN rm -rf /usr/local/bin/tini.asc
RUN chmod +x /usr/local/bin/tini
RUN tini -h

# Logstash
# https://www.elastic.co/guide/en/logstash/5.6/docker.html
ENV LOGSTASH_VERSION 5.6.12
ENV LOGSTASH_HOME /usr/share/logstash
WORKDIR ${LOGSTASH_HOME}

# Install from tar file
RUN wget https://artifacts.elastic.co/downloads/logstash/logstash-${LOGSTASH_VERSION}.tar.gz
RUN sha1sum logstash-${LOGSTASH_VERSION}.tar.gz
RUN tar -xzf logstash-${LOGSTASH_VERSION}.tar.gz -C ${LOGSTASH_HOME} --strip-components 1
RUN rm logstash-${LOGSTASH_VERSION}.tar.gz

ENV PATH ${LOGSTASH_HOME}/bin:$PATH

# https://discuss.elastic.co/t/i-cannot-run-logstash-on-raspberry-pi3/109789
# /usr/share/logstash/vendor/jruby/lib/jni/arm-Linux/libjffi-1.2.so
RUN git clone https://github.com/jnr/jffi.git
RUN mkdir -p ${LOGSTASH_HOME}/vendor/jruby/lib/jni/arm-Linux
RUN cd jffi && \
  ant jar && \
  cp build/jni/libjffi-1.2.so ${LOGSTASH_HOME}/vendor/jruby/lib/jni/arm-Linux/
RUN rm -rf ./jffi
RUN apt-get remove --purge -y git

# # the default "server.host" is "localhost" in 5+
# RUN sed -ri "s!^(\#\s*)?(server\.host:).*!\2 '0.0.0.0'!" ${LOGSTASH_HOME}/config/logstash.yml
# RUN grep -q "^server\.host: '0.0.0.0'\$" ${LOGSTASH_HOME}/config/logstash.yml
# # ensure the default configuration is useful when using --link
# RUN sed -ri "s!^(\#\s*)?(elasticsearch\.url:).*!\2 'http://elasticsearch:9200'!" ${LOGSTASH_HOME}/config/logstash.yml
# RUN grep -q "^elasticsearch\.url: 'http://elasticsearch:9200'\$" ${LOGSTASH_HOME}/config/logstash.yml

ENV LOGSTASH_HOME /usr/share/logstash
ENV LS_SETTINGS_DIR ${LOGSTASH_HOME}/config
# comment out some troublesome configuration parameters
#   path.config: No config files found: /etc/logstash/conf.d/*
RUN set -ex; \
	if [ -f "$LS_SETTINGS_DIR/logstash.yml" ]; then \
		sed -ri 's!^path\.config:!#&!g' "$LS_SETTINGS_DIR/logstash.yml"; \
	fi; \
# Lower java initial heap size in jvm.options
	if [ -f "$LS_SETTINGS_DIR/jvm.options" ]; then \
	  sed -ri 's/^-Xms1g/-Xms500m/g' "$LS_SETTINGS_DIR/jvm.options"; \
	  sed -ri 's/^-Xmx1g/-Xmx500m/g' "$LS_SETTINGS_DIR/jvm.options"; \
	fi; \
# if the "log4j2.properties" file exists (logstash 5.x),
# let's empty it out so we get the default:
# "logging only errors to the console"
	if [ -f "$LS_SETTINGS_DIR/log4j2.properties" ]; then \
		cp "$LS_SETTINGS_DIR/log4j2.properties" "$LS_SETTINGS_DIR/log4j2.properties.dist"; \
		truncate --size=0 "$LS_SETTINGS_DIR/log4j2.properties"; \
	fi;

# Symlink the config file changes made
# to the config files logstash uses by default
RUN mkdir -p /etc/logstash
COPY logstash.conf ${LOGSTASH_HOME}/config/logstash.yml
RUN ln -sf ${LOGSTASH_HOME}/config/logstash.yml /etc/logstash/logstash.yml
RUN ln -sf ${LOGSTASH_HOME}/config/log4j2.properties /etc/logstash/log4j2.properties
RUN ln -sf ${LOGSTASH_HOME}/config/jvm.options /etc/logstash/jvm.options
RUN chown -R logstash:logstash ${LOGSTASH_HOME}
RUN chown -R logstash:logstash /etc/logstash

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["-e", ""]
