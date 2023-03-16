FROM alpine:edge
MAINTAINER Brice Dereims "bdereims@gmail.com" 

RUN set -xe \
    && apk update && apk add --no-cache ca-certificates \
        gzip wget \
        nginx \
        openssl \
        tar \
	php7-fpm php7 php7-ctype php7-dom php7-gd php7-iconv \
	php7-json php7-xml php7-mbstring php7-posix php7-zip \
	php7-zlib php7-session php7-mcrypt php7-json php7-curl \
	php7-gd php7-openssl 
#	    && touch /etc/php7/fpm.d/empty.conf

COPY nginx.conf /etc/nginx/nginx.conf
COPY startup.sh /opt/startup.sh

VOLUME /var/www/html/dokuwiki/conf \
       /var/www/html/dokuwiki/data/pages \
       /var/www/html/dokuwiki/data/meta \
       /var/www/html/dokuwiki/data/media \
       /var/www/html/dokuwiki/data/media_attic \
       /var/www/html/dokuwiki/data/media_meta \
       /var/www/html/dokuwiki/data/attic \
       /var/www/html/dokuwiki/lib/plugins

EXPOSE 80

CMD ["/bin/sh", "/opt/startup.sh"]
