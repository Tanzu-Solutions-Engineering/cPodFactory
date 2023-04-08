CONTAINER_NAME=syncthing
IMAGE_NAME=cpod/${CONTAINER_NAME}
VOLUME=/data/Syncthing

build: Dockerfile
	docker build -t $(IMAGE_NAME) .

start:
	docker run -d -p 8384:8384 -p 22000:22000 \
	-v ${VOLUME}/config:/var/syncthing/config \
	-v ${VOLUME}/Sync:/var/syncthing/Sync \
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

