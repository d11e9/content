container_name = "content.datagotchi.com"

all: build stop run

stop:
	docker kill $(container_name); \
	docker rm $(container_name);

build:
	docker build -t $(container_name) .

run:
	docker run -d --link redis:redis --link eth.datagotchi.com:eth --name $(container_name) -t $(container_name); docker logs -f $(container_name);

