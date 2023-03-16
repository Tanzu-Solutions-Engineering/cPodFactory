#!/bin/bash
#edewitte@vmware.com

# $1 : Name of cpod to modify
# $2 : Name of owner

START=$( date +%s ) 

[ "$1" == ""  ] && echo "usage: $0 <name_of_user>"  && echo "usage example: $0 edewitte" && exit 1

echo "Checking if user exists"

if id -u "$1" >/dev/null 2>&1; then
  echo "user exists"
else
  echo "user does not exist"
  exit 1
fi

echo "deleting user"
userdel  $1 -f -r

END=$( date +%s )
TIME=$( expr ${END} - ${START} )

echo
echo "=========================="
echo "=== user deleted  ========"
echo "=== In ${TIME} Seconds ==="
echo "=========================="

