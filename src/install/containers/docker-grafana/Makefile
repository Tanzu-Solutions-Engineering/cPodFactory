CONTAINER_NAME=grafana
IMAGE_NAME=cpod/${CONTAINER_NAME}
VOLUME=/data/volumes/${CONTAINER_NAME}

build: Dockerfile
	docker build -t $(IMAGE_NAME) .

start:
	docker run -d -p 3000:3000 --dns 172.16.100.50 \
	-v ${VOLUME}:/var/lib/grafana \
	-e "GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource" \
	-e "GF_SECURITY_ADMIN_PASSWORD=secret" \
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

