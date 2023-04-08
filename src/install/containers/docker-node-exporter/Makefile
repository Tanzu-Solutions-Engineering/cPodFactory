CONTAINER_NAME=node-exporter
IMAGE_NAME=cpod/${CONTAINER_NAME}
VOLUME=/data/volumes/${CONTAINER_NAME}

build: Dockerfile
	docker build -t $(IMAGE_NAME) .

start:
	docker run -d --dns 10.1.0.150 \
	--net="host" \
	--pid="host" \
	-v "/:/host:ro,rslave" \
	--name ${CONTAINER_NAME} \
	${IMAGE_NAME} \
	--path.rootfs /host	

stop:
	docker stop $(CONTAINER_NAME) 
	docker rm $(CONTAINER_NAME) 

clean: 
	docker rmi $(IMAGE_NAME) 
	docker images

clean-volume:
	rm -fr $(VOLUME)/{*,.??*}

