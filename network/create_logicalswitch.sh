#!/bin/bash
#bdereims@vmware.com

. ./env

[ "$1" == "" -o "$2" == "" ] && echo "usage: $0 <name_of_transportzone> <name_of_logicalswitch>" && exit 1 


TZ_ID=$( ${NETWORK_DIR}/id_transportzone.sh ${1} )
[ "${TZ_ID}" == "" ] && echo "${1} doesn't exist!" && exit 1

case $BACKEND_NETWORK in
	"NSX-V")

		#NEW_LOGICALSWITCH="<virtualWireCreateSpec><name>${2}</name><description>Logical Switch via REST API</description><tenantId></tenantId><controlPlaneMode>HYBRID_MODE</controlPlaneMode><guestVlanAllowed>true</guestVlanAllowed></virtualWireCreateSpec>"
		NEW_LOGICALSWITCH="<virtualWireCreateSpec><name>${2}</name><description>Logical Switch via REST API</description><tenantId></tenantId><controlPlaneMode>HYBRID_MODE</controlPlaneMode><guestVlanAllowed>true</guestVlanAllowed></virtualWireCreateSpec>"

		curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -H "Content-Type:text/xml;charset=UTF-8" -X POST --data "${NEW_LOGICALSWITCH}" https://${NSX}/api/2.0/vdn/scopes/${TZ_ID}/virtualwires 2>&1 > /dev/null

		LS_PROPS=$( ${NETWORK_DIR}/props_logicialswitch.sh $1 $2 )

		[ "${LS_PROPS}" != "" ] && echo "Logicial Switch '${2}' has been sucessfully created in '${1}'." && exit 0

		echo "Logical Switch '${2}' does not seem to be created." && exit 1

		;;
    "NSX-T")
		if [ "${NSXTVIDM}" == "YES" ]; then
			REMOTE64=$(echo -n "${NSX_ADMIN}:${NSX_PASSWD}" | base64 )
			curl -s -k -H "Authorization: Remote ${REMOTE64}" -X PUT -H "Content-Type: application/json" --data  "{\"display_name\":\"${2}\",\"transport_zone_path\":\"/infra/sites/default/enforcement-points/default/transport-zones/${NSX_TRANSPORTZONE_ID}\",\"vlan_ids\":[\"0-4094\"]}" https://${NSX}/policy/api/v1/infra/segments/${2} 2>&1 > /dev/null
			curl -s -k -H "Authorization: Remote ${REMOTE64}" -X PUT -H "Content-Type: application/json" -d "{\"spoofguard_profile_path\":\"/infra/spoofguard-profiles/default-spoofguard-profile\",\"segment_security_profile_path\":\"/infra/segment-security-profiles/cpod-segment-security-profile\",\"resource_type\":\"SegmentSecurityProfileBindingMap\"}" https://${NSX}/policy/api/v1/infra/segments/${2}/segment-security-profile-binding-maps/segment_security_binding_map_${2} 2>&1 > /dev/null
			curl -s -k -H "Authorization: Remote ${REMOTE64}" -X PUT -H "Content-Type: application/json" -d "{\"mac_discovery_profile_path\":\"/infra/mac-discovery-profiles/cpod-mac-discovery-profile\",\"ip_discovery_profile_path\":\"/infra/ip-discovery-profiles/cpod-ip-discovery-profile\",\"resource_type\":\"SegmentDiscoveryProfileBindingMap\"}" https://${NSX}/policy/api/v1/infra/segments/${2}/segment-discovery-profile-binding-maps/segment_discovery_binding_map_${2}  2>&1 > /dev/null
		else
			curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X PUT -H "Content-Type: application/json" --data  "{\"display_name\":\"${2}\",\"transport_zone_path\":\"/infra/sites/default/enforcement-points/default/transport-zones/${NSX_TRANSPORTZONE_ID}\",\"vlan_ids\":[\"0-4094\"]}" https://${NSX}/policy/api/v1/infra/segments/${2} 2>&1 > /dev/null
			curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X PUT -H "Content-Type: application/json" -d "{\"spoofguard_profile_path\":\"/infra/spoofguard-profiles/default-spoofguard-profile\",\"segment_security_profile_path\":\"/infra/segment-security-profiles/cpod-segment-security-profile\",\"resource_type\":\"SegmentSecurityProfileBindingMap\"}" https://${NSX}/policy/api/v1/infra/segments/${2}/segment-security-profile-binding-maps/segment_security_binding_map_${2} 2>&1 > /dev/null
			curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X PUT -H "Content-Type: application/json" -d "{\"mac_discovery_profile_path\":\"/infra/mac-discovery-profiles/cpod-mac-discovery-profile\",\"ip_discovery_profile_path\":\"/infra/ip-discovery-profiles/cpod-ip-discovery-profile\",\"resource_type\":\"SegmentDiscoveryProfileBindingMap\"}" https://${NSX}/policy/api/v1/infra/segments/${2}/segment-discovery-profile-binding-maps/segment_discovery_binding_map_${2} 2>&1 > /dev/null
		fi
		;;
esac
