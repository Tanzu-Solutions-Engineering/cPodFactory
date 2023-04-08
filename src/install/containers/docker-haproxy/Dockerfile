FROM alpine 
MAINTAINER Brice Dereims "bdereims@gmail.com"

# Install HAProxy
RUN apk update && apk upgrade && \
	apk add haproxy

# Add HAProxy default config 
ADD haproxy/conf /etc/haproxy/.
RUN mkdir -p /var/lib/haproxy \
	&& chown -R haproxy:haproxy /var/lib/haproxy \ 
	&& chmod 600 /etc/haproxy/*

ADD startup.sh /opt/startup.sh

EXPOSE 80 443 1936

CMD ["/bin/sh", "/opt/startup.sh"]
