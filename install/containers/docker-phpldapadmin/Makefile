CONTAINER_NAME=phpldapadmin
IMAGE_NAME=cpod/${CONTAINER_NAME}
VOLUME=

build: Dockerfile
	docker build -t $(IMAGE_NAME) .

start:
	docker run -d \
	-p 8082:80 -p 8433:433 \
	--hostname phpldapadmin-service \
	--link openldap:ldap-host \
	--env PHPLDAPADMIN_LDAP_HOSTS=ldap-host \
	--env PHPLDAPADMIN_HTTPS=false \
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

