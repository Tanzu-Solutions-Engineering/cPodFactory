openssl genrsa -out cpodedge.key 2048
openssl req -new -key cpodedge.key -out cpodedge.csr
openssl x509 -req -days 3650 -in cpodedge.csr -signkey cpodedge.key -out cpodedge.crt
cat cpodedge.key cpodedge.crt > haproxy/conf/cpodedge.pem
