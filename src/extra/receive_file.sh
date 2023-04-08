#!/bin/bash -e
#bdereims@vmware.com

PORT=7000

netcat -l -p ${PORT} | pv | tar x
