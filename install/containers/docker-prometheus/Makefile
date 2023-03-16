CONTAINER_NAME=prometheus
IMAGE_NAME=cpod/${CONTAINER_NAME}
VOLUME=/data/volumes/${CONTAINER_NAME}

build: Dockerfile
	docker build -t $(IMAGE_NAME) .

start:
	docker run -d -p 9090:9090 --dns 10.1.0.150 \
	-v ${VOLUME}:/prometheus-data \
	--name ${CONTAINER_NAME} \
	${IMAGE_NAME} 
	#${IMAGE_NAME} --config.file=/prometheus-data/prometheus.yml

stop:
	docker stop $(CONTAINER_NAME) 
	docker rm $(CONTAINER_NAME) 

clean: 
	docker rmi $(IMAGE_NAME) 
	docker images

clean-volume:
	rm -fr $(VOLUME)/{*,.??*}

