# docker-openvpn

# setup

edit openvpn/easy-rsa/vars
```
cd openvpn/easy-rsa/
source ./vars

./clean-all

./build-dh
./build-ca
./build-key cpodedge
./build-key client
```

## build openvpn container

```
make stop
make clean
make build
make start
```
docker logs openvpn

## revoking client

```
cd openvpn/easy-rsa/
source ./vars
cat keys/index.txt
```
lines with V in front = Valid
lines with R in front = Revoked

```
./revoke-full client
cat keys/index.txt
```

once done, rebuild container again - see [build openvpn container](#build-openvpn-container)


