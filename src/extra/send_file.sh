#!/bin/bash -e
#bdereims@vmware.com

# $1 : which file
# $2 : to which box, i.e. the receiver

PORT=7000

tar cf - ${1} | pv | netcat ${2} ${PORT}
