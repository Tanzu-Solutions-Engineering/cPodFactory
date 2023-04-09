#!/bin/bash
#bdereims@vmware.com

pushd ~/cPodFactory
. ./env
popd

cd openvpn
eval "echo \"$(cat server.conf-template)\"" > server.conf
