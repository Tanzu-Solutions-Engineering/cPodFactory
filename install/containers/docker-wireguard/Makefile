CONTAINER_NAME=wireguard
IMAGE_NAME=cpod/${CONTAINER_NAME}
VOLUME=/data/volumes/wireguard

build: Dockerfile
	docker build -t $(IMAGE_NAME) .

start:
	docker run -d \
	--net=host \
	--device=/dev/net/tun \
	--cap-add=NET_ADMIN \
	--restart=always \
	--name $(CONTAINER_NAME) $(IMAGE_NAME)

stop:
	docker stop $(CONTAINER_NAME) 
	docker rm $(CONTAINER_NAME) 

clean: 
	docker rmi $(IMAGE_NAME) 
	docker images

clean-volume:
	rm -fr $(VOLUME)/{*,.??*}

