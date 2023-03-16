docker run \
    -p 9090:9090 \
    -v /root/cPodFactory/install/containers/docker-prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
    prom/prometheus
