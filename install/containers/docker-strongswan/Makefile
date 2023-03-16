CONTAINER_NAME=strongswan
IMAGE_NAME=cpod/${CONTAINER_NAME}
VOLUME=/data/volumes/strongswan

build: Dockerfile
	mkdir -p $(VOLUME)
	cp -R config $(VOLUME)
	docker build -t $(IMAGE_NAME) .

start:
	docker run -d \
	--cap-add=NET_ADMIN \
	--net=host \
	-v $(VOLUME)/config/strongswan.conf:/etc/strongswan.conf \
	-v $(VOLUME)/config/ipsec.conf:/etc/ipsec.conf \
	-v $(VOLUME)/config/ipsec.secrets:/etc/ipsec.secrets \
	-v $(VOLUME)/config/ipsec.d:/etc/ipsec.d \
	--name $(CONTAINER_NAME) $(IMAGE_NAME)

stop:
	docker stop $(CONTAINER_NAME) 
	docker rm $(CONTAINER_NAME) 

clean: 
	docker rmi $(IMAGE_NAME) 
	docker images

clean-volume:
	rm -fr $(VOLUME)/{*,.??*}
