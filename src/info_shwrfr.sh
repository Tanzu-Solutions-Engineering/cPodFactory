#!/bin/bash
#bdereims@vmware.com

. ./env
. ./govc_env

main() {
	INFO=$( govc datastore.info )
	echo $INFO
	#./extra/post_slack.sh "Deleting cPod *${NAME_HIGH}*"
}

main $1
