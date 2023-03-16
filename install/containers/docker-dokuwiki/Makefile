CONTAINER_NAME=dokuwiki
IMAGE_NAME=cpod/${CONTAINER_NAME}
VOLUME=/data/volumes/dokuwiki-data

build: Dockerfile
	mkdir -p $(VOLUME)
	docker build -t $(IMAGE_NAME) .

start:
	docker run -d \
	-p 8083:80 \
	-v $(VOLUME)/conf:/var/www/html/dokuwiki/conf \
	-v $(VOLUME)/data/pages:/var/www/html/dokuwiki/data/pages \
	-v $(VOLUME)/data/meta:/var/www/html/dokuwiki/data/meta \
	-v $(VOLUME)/data/media:/var/www/html/dokuwiki/data/media \
	-v $(VOLUME)/data/media_attic:/var/www/html/dokuwiki/data/media_attic \
	-v $(VOLUME)/data/media_meta:/var/www/html/dokuwiki/data/media_meta \
	-v $(VOLUME)/data/attic:/var/www/html/dokuwiki/data/attic \
	-v $(VOLUME)/lib/plugins:/var/www/html/dokuwiki/lib/plugins \
	--name $(CONTAINER_NAME) $(IMAGE_NAME)

stop:
	docker stop $(CONTAINER_NAME) 
	docker rm $(CONTAINER_NAME) 

clean: 
	docker rmi $(IMAGE_NAME) 
	docker images

backup:
	PWD=`pwd` && \
	cd $(VOLUME) && \
	tar cvzf $(PWD)/backup.tgz . 

restore:
	PWD=`pwd` && \
	cd $(VOLUME) && \
	tar xvzf $(PWD)/backup.tgz

clean-volume:
	rm -fr $(VOLUME)/{*,.??*}

