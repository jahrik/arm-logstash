FROM jahrik/arm-gosu-tini:aarch64

# Add logstash user and group first to make sure their IDs get assigned consistently
RUN groupadd -r logstash && useradd -r -m -g logstash logstash

# Dependencies
# returned a non-zero code: 100
RUN apt-get update && apt-get install -y \
  openjdk-8-jdk-headless \
  wget \
  # git \
  # ant \
  && rm -rf /var/lib/apt/lists/*

# the "ffi-rzmq-core" gem is very picky about where it looks for libzmq.so
RUN mkdir -p /usr/local/lib \
	&& ln -s /usr/lib/*/libzmq.so.3 /usr/local/lib/libzmq.so

# https://discuss.elastic.co/t/i-cannot-run-logstash-on-raspberry-pi3/109789
# /usr/share/logstash/vendor/jruby/lib/jni/arm-Linux/libjffi-1.2.so
RUN git clone https://github.com/jnr/jffi.git
RUN mkdir -p ${LS_HOME}/vendor/jruby/lib/jni/aarch64-Linux
RUN cd jffi && \
  ant jar && \
  cp build/jni/libjffi-1.2.so ${LS_HOME}/vendor/jruby/lib/jni/aarch64-Linux/
RUN rm -rf ./jffi
RUN apt-get remove --purge -y git ant

# Logstash
# https://www.elastic.co/guide/en/logstash/5.6/docker.html
ENV LS_VERSION 5.6.12
ENV LS_URL https://artifacts.elastic.co/downloads/logstash/
ENV LS_HOME /usr/share/logstash
WORKDIR ${LS_HOME}
RUN wget ${LS_URL}logstash-${LS_VERSION}.deb && \
  dpkg -i logstash-${LS_VERSION}.deb && \
  rm logstash-${LS_VERSION}.deb

# # Install from tar file
# RUN wget https://artifacts.elastic.co/downloads/logstash/logstash-${LS_VERSION}.tar.gz
# RUN sha1sum logstash-${LS_VERSION}.tar.gz
# RUN tar -xzf logstash-${LS_VERSION}.tar.gz -C ${LS_HOME} --strip-components 1
# RUN rm logstash-${LS_VERSION}.tar.gz

ENV PATH ${LS_HOME}/bin:$PATH

# Symlink the config files
ENV LS_ETC /etc/logstash
RUN mkdir -p ${LS_ETC}
RUN mkdir -p ${LS_HOME}/config

COPY logstash.conf ${LS_ETC}/logstash.conf
RUN ln -sf ${LS_ETC}/log4j2.properties ${LS_HOME}/config/log4j2.properties
RUN ln -sf ${LS_ETC}/logstash.yml ${LS_HOME}/config/logstash.yml
RUN ln -sf ${LS_ETC}/jvm.options ${LS_HOME}/config/jvm.options
RUN chown -R logstash:logstash ${LS_HOME}
RUN chown -R logstash:logstash ${LS_ETC}

# comment out some troublesome configuration parameters
#   path.config: No config files found: /etc/logstash/conf.d/*
RUN set -ex; \
	if [ -f "$LS_ETC/logstash.yml" ]; then \
		sed -ri 's!^path\.config:!#&!g' "$LS_ETC/logstash.yml"; \
	fi; \
# Lower java initial heap size in jvm.options
	if [ -f "$LS_ETC/jvm.options" ]; then \
	  sed -ri 's/^-Xms1g/-Xms500m/g' "$LS_ETC/jvm.options"; \
	  sed -ri 's/^-Xmx1g/-Xmx500m/g' "$LS_ETC/jvm.options"; \
	fi; \
# if the "log4j2.properties" file exists (logstash 5.x),
# let's empty it out so we get the default:
# "logging only errors to the console"
	if [ -f "$LS_ETC/log4j2.properties" ]; then \
		cp "$LS_ETC/log4j2.properties" "$LS_ETC/log4j2.properties.dist"; \
		truncate --size=0 "$LS_ETC/log4j2.properties"; \
	fi;

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

EXPOSE 5000 5044
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["-f", "/etc/logstash/logstash.conf"]
