CONTAINER_NAME=elasticsearch
IMAGE_NAME=cpod/${CONTAINER_NAME}
VOLUME=/data/volumes/${CONTAINER_NAME}

build: Dockerfile
	docker build -t $(IMAGE_NAME) .

start:
	docker run -d -p 9200:9200 -p 9300:9300 --dns 172.16.100.50 \
	-v ${VOLUME}:/usr/share/elasticsearch/data \
	-e "discovery.type=single-node" \
	--name ${CONTAINER_NAME} \
	${IMAGE_NAME}

stop:
	docker stop $(CONTAINER_NAME) 
	docker rm $(CONTAINER_NAME) 

clean: 
	docker rmi $(IMAGE_NAME) 
	docker images

clean-volume:
	rm -fr $(VOLUME)/{*,.??*}

