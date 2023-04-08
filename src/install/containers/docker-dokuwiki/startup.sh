#!/bin/sh
#bdereims@gmail.com

DOKUDIR=/var/www/html/dokuwiki

if [ ! -f "${DOKUDIR}/INSTALLED" ]; then
	mkdir -p ${DOKUDIR}
	cd ${DOKUDIR}
 
	wget -O- http://download.dokuwiki.org/src/dokuwiki/dokuwiki-stable.tgz | tar xz --strip 1
	chown -R nobody:nobody .
fi

touch ${DOKUDIR}/INSTALLED

#php-fpm5 && nginx -g 'daemon off;'
php-fpm7 && nginx -g 'daemon off;'
