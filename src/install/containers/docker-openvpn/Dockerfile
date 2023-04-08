FROM alpine 
MAINTAINER Brice Dereims "bdereims@gmail.com"

# Install OpenVPN 
RUN apk update && apk upgrade && \
	apk add openvpn openssl

# Add OpenVPN default config 
ADD openvpn /etc/openvpn/.
RUN mkdir -p /run/openvpn

ADD startup.sh /opt/startup.sh

EXPOSE 1194

CMD ["/bin/sh", "/opt/startup.sh"]
