.EXPORT_ALL_VARIABLES:
IMAGE = "jahrik/arm-logstash"
TAG = latest
STACK = "elk"

all: build

build:
	@docker build -t ${IMAGE}:$(TAG) .

push:
	@docker push ${IMAGE}:$(TAG)

deploy:
	@docker stack deploy -c docker-compose.yml ${STACK}

.PHONY: all build push deploy
