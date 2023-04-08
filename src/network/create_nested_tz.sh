#!/bin/bash
#bdereims@vmware.com

. ./src/env

case $BACKEND_NETWORK in
	"NSX-V")
		# nothing to do here
		exit 0
		;;
	"NSX-T")
		# create transport zone to host nested esx
		MODIFY="{\"display_name\":\"tz-cpod\",\"host_switch_name\":\"nsxDefaultHostSwitch\",\"nested_nsx\":true,\"description\":\"Transport Zone for cPod\",\"transport_type\":\"OVERLAY\"}"
		echo $MODIFY
		curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X POST -H "Content-Type: application/json" --data @${NETWORK_DIR}/nested-tz.json https://${NSX}/api/v1/transport-zones/
		;;
esac
