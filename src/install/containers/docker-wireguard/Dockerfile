FROM alpine 
MAINTAINER Brice Dereims "bdereims@gmail.com"

# Install WireGuard 
RUN apk update && apk upgrade && \
	apk add wireguard-tools

ADD startup.sh /opt/startup.sh

CMD ["/bin/sh", "/opt/startup.sh"]
