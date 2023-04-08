#!/bin/bash
#bdereims@vmware.com
#update repo definition, repo server have changed

cd /etc/yum.repos.d/
sed  -i 's/dl.bintray.com\/vmware/packages.vmware.com\/photon\/$releasever/g' photon.repo photon-updates.repo photon-extras.repo photon-debuginfo.repo

tdnf update
