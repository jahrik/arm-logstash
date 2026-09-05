image := "jahrik/arm-logstash"
tag := "latest"
platforms := "linux/amd64,linux/arm64"
stack := "elk"

# Build the image locally
[group('build')]
build image_name=image image_tag=tag:
    docker build -t {{ image_name }}:{{ image_tag }} .

# Push the image to its default registry
[group('build')]
push image_name=image image_tag=tag:
    docker push {{ image_name }}:{{ image_tag }}

# Log in to a container registry (used by CI before release)
[group('release')]
login registry="docker.io" username="" password="":
    echo "{{ password }}" | docker login {{ registry }} -u "{{ username }}" --password-stdin

# Multi-arch build and push (used by CI release job)
[group('release')]
release tags=(image + ":" + tag):
    docker buildx build --platform {{ platforms }} -t {{ tags }} --push .

# Deploy the compose stack to the swarm
[group('deploy')]
deploy stack=stack:
    docker stack deploy -c docker-compose.yml {{ stack }}
