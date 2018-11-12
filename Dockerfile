FROM jahrik/arm-gosu-tini:aarch64

# Add logstash user and group first to make sure their IDs get assigned consistently
RUN groupadd -r logstash && useradd -r -m -g logstash logstash

# Dependencies
# returned a non-zero code: 100
RUN apt-get update && apt-get install -y \
  openjdk-8-jdk-headless \
  wget \
  git \
  ant \
  && rm -rf /var/lib/apt/lists/*

# # the "ffi-rzmq-core" gem is very picky about where it looks for libzmq.so
# RUN mkdir -p /usr/local/lib \
# 	&& ln -s /usr/lib/*/libzmq.so.3 /usr/local/lib/libzmq.so

# https://discuss.elastic.co/t/i-cannot-run-logstash-on-raspberry-pi3/109789
# /usr/share/logstash/vendor/jruby/lib/jni/arm-Linux/libjffi-1.2.so
RUN git clone https://github.com/jnr/jffi.git
RUN mkdir -p ${LOGSTASH_HOME}/vendor/jruby/lib/jni/arm-Linux
RUN cd jffi && \
  ant jar && \
  cp build/jni/libjffi-1.2.so ${LOGSTASH_HOME}/vendor/jruby/lib/jni/arm-Linux/
RUN rm -rf ./jffi
RUN apt-get remove --purge -y git

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

# Symlink the config files
ENV LOGSTASH_ETC /etc/logstash
RUN mkdir -p ${LOGSTASH_ETC}
COPY logstash.conf ${LOGSTASH_ETC}/logstash.conf
RUN ln -sf ${LOGSTASH_HOME}/config/log4j2.properties ${LOGSTASH_ETC}/log4j2.properties
RUN ln -sf ${LOGSTASH_HOME}/config/logstash.yml ${LOGSTASH_ETC}/logstash.yml
RUN ln -sf ${LOGSTASH_HOME}/config/jvm.options ${LOGSTASH_ETC}/jvm.options
RUN chown -R logstash:logstash ${LOGSTASH_HOME}
RUN chown -R logstash:logstash ${LOGSTASH_ETC}

# comment out some troublesome configuration parameters
#   path.config: No config files found: /etc/logstash/conf.d/*
RUN set -ex; \
	if [ -f "$LOGSTASH_ETC/logstash.yml" ]; then \
		sed -ri 's!^path\.config:!#&!g' "$LOGSTASH_ETC/logstash.yml"; \
	fi; \
# Lower java initial heap size in jvm.options
	if [ -f "$LOGSTASH_ETC/jvm.options" ]; then \
	  sed -ri 's/^-Xms1g/-Xms500m/g' "$LOGSTASH_ETC/jvm.options"; \
	  sed -ri 's/^-Xmx1g/-Xmx500m/g' "$LOGSTASH_ETC/jvm.options"; \
	fi; \
# if the "log4j2.properties" file exists (logstash 5.x),
# let's empty it out so we get the default:
# "logging only errors to the console"
	if [ -f "$LOGSTASH_ETC/log4j2.properties" ]; then \
		cp "$LOGSTASH_ETC/log4j2.properties" "$LOGSTASH_ETC/log4j2.properties.dist"; \
		truncate --size=0 "$LOGSTASH_ETC/log4j2.properties"; \
	fi;

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["-f", "/etc/logstash/logstash.conf"]
