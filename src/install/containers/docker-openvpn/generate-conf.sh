#!/bin/bash
#bdereims@vmware.com

pushd ~/cPodFactory
. ./src/env
popd

cd openvpn
eval "echo \"$(cat server.conf-template)\"" > server.conf
