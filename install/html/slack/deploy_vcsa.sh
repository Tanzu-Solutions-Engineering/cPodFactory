#!/bin/bash

tmux new -d "cd /root/cPodFactory ; bash -x ./extra/deploy_vcsa.sh $1 $2"
