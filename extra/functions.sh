#!/bin/bash
#bdereims@vmware.com

export GOVC_USERNAME="${VCENTER_ADMIN}"
export GOVC_PASSWORD=${VCENTER_PASSWD}
export GOVC_URL="${VCENTER}"
export GOVC_INSECURE=1
export GOVC_DATACENTER="${VCENTER_DATACENTER}"
export GOVC_DATASTORE="${VCENTER_DATASTORE}"

replace_json() {
	TEMP=/tmp/$$

	# ${1} : Source File
	# ${2} : Nested Item
	# ${3} : Key to find
	# ${4} : Value of Key
	# ${5} : Key to update
	# ${6} : Update Key

	cat ${1} | \
	jq '(.'"${2}"'[] | select (.'"${3}"' == "'"${4}"'") | .'"${5}"') = "'"${6}"'"' > ${1}-tmp

	cp ${1}-tmp ${1} ; rm ${1}-tmp
}

test_params_file() {
	[ "$1" == "" ] && echo "usage: $0 <filename>" && exit 1 

	FILELIST=$(cat ${1}  | grep "=/" | cut -d"=" -f2)
	PROBLEM="none"
	for FileToCheck in ${FILELIST}; do
		if [ -f "$FileToCheck" ]; then
			echo "	ok - ${FileToCheck}"
		else
			echo "	NOT FOUND - "$(cat ${1} | grep ${FileToCheck} )
			PROBLEM="YES"
		fi
	done

	TEMPLATENAME=$(cat ${1}  | grep "ESX" | cut -d"=" -f2)
	TEMPLATE=$(govc ls /${VCENTER_DATACENTER}/vm/${TEMPLATE_FOLDER}/${TEMPLATENAME})
	if [ "${TEMPLATE}" == "" ]; then
		echo "	Template ${TEMPLATENAME} not found"
		PROBLEM="YES"
	else
		echo "	ok - Template ${TEMPLATENAME}"
	fi

	if [ ${PROBLEM} == "YES" ]; then
		exit 1
	fi
}

add_to_cpodrouter_dnsmasq() {
	# ${1} : line to add to dnsmasq
	# ${2} : cpod_name_lower

	echo "add ${1} to ${2}"
	ssh -o LogLevel=error ${CPOD_NAME_LOWER} "sed "/${1}/d" -i /etc/dnsmasq.conf ; printf \"${1}\n\" >> /etc/dnsmasq.conf"
	ssh -o LogLevel=error ${CPOD_NAME_LOWER} "systemctl restart dnsmasq.service"
}

add_to_cpodrouter_hosts() {
	# ${1} : ip address to add
	# ${2} : host record to add
	# ${3} : cpod_name_lower to add to

	echo "add ${1} -> ${2} in ${3}"
	ssh -o LogLevel=error ${3} "sed "/${1}/d" -i /etc/hosts ; printf \"${1}\\t${2}\\n\" >> /etc/hosts"
	ssh -o LogLevel=error ${3} "systemctl restart dnsmasq.service"
}

enable_dhcp_cpod_vlanx() {
	# ${1} : internal cpod vlan (1-8) to enable dhcp on
	# ${2} : cpod_name_lower
	# example : enable_dhcp_cpod_vlanx 2 cpod-demo.az-stc.cloud-garage.net

	
	#dhcp-range=eth2.1047:eth2,10.104.7.2,10.104.7.254,255.255.255.0,12h
	#dhcp-option=eth2.1047:eth2,option:router,10.104.7.1
	echo "TBD"
}

get_last_ip() {
	# ${1} : subnet
	# ${2} : cpod_name_lower to query

	SUBNET=${1}
	CPOD=${2}
	LASTIP=$(ssh -o LogLevel=error ${CPOD} "cat /etc/hosts | grep ${SUBNET}" | awk '{print $1}' | sort -t . -k 2,2n -k 3,3n -k 4,4n | tail -n 1 | cut -d "." -f 4)
	echo $LASTIP
}