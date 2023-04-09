FROM ubuntu:22.04

RUN apt-get update \
  && apt-get upgrade \
  && apt-get install -y net-tools \
  && apt-get install -y iproute2 \
  && apt-get update

ADD src/ /root/cPodFactory/src/
ADD test/ /root/cPodFactory/test/

ENTRYPOINT ["/root/cPodFactory/test/bats/bin/bats","-T"]