#!/bin/bash
#edewitte@vmware.com

source ./env
ls -rlhSog $CPODEDGE_DATASTORE |grep "G " | awk '{$1=$2=$4=$5=$6=""; print}'