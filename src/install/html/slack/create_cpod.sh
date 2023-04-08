#!/bin/bash

cd /root/cPodFactory
./cpodctl create $1 $2 $3

#ENV="Name:${1} #ESX:${2} Owner:${3}" 
