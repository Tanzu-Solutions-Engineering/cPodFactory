#!/bin/bash
#edewitte@vmware.com

# $1 : Name of cpod to modify
# $2 : Name of owner

START=$( date +%s ) 

[ "$1" == ""  ] && echo "usage: $0 <name_of_user>"  && echo "usage example: $0 edewitte" && exit 1


echo "Checking if user already exists"

if id -u "$1" >/dev/null 2>&1; then
  echo "user already exists"
  exit 1
else
  echo "user does not exist"
fi

echo "creating user"
useradd $1

echo "creating home directory"
mkdir /home/$1
chown $1 /home/$1

echo "assign password"
GEN_PASSWORD="$(pwgen -s -1 11 1)!"
echo "$1:${GEN_PASSWORD}" | chpasswd


END=$( date +%s )
TIME=$( expr ${END} - ${START} )

echo
echo "==============================================="
echo "===  user created"
echo "===  In ${TIME} Seconds"
echo "==============================================="
echo "===  user name : $1"
echo "===  user password : ${GEN_PASSWORD}"
echo "===  user home directory : /home/$1"
echo "==============================================="
