CONTAINER_NAME=openldap
IMAGE_NAME=cpod/${CONTAINER_NAME}
VOLUME=

build: Dockerfile
	docker build -t $(IMAGE_NAME) .

start:
	docker run -d \
	-p 389:389 -p 636:636 \
	--hostname ldap-host \
	--env LDAP_ORGANISATION="cloud-garage" \
	--env LDAP_DOMAIN="cloud-garage.net" \
	--env LDAP_BASE_DN="dc=cloud-garage,dc=net" \
	--hostname ldap-host \
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

