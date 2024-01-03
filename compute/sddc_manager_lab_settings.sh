#!/bin/bash
#edewitte@vmware.com
# Script to be executed on cloudbuilder via vmtools remote exec.

[ -f /home/admin/labsettings_done ] && echo "Lab settings already set" && exit 

SETTINGSFILE="/etc/vmware/vcf/domainmanager/application.properties"
echo "${SETTINGSFILE}"

chmod 600 "${SETTINGSFILE}"
echo "#Lab sizing entries" >> ${SETTINGSFILE}
echo "nsxt.manager.formfactor=small" >> ${SETTINGSFILE}
echo "nsxt.manager.wait.minutes=45" >> ${SETTINGSFILE}
echo "nsxt.manager.cluster.size=1" >> ${SETTINGSFILE}
echo "nsxt.management.resources.validation.skip=true" >> ${SETTINGSFILE}
chmod 400 "${SETTINGSFILE}"
systemctl restart domainmanager
touch /home/admin/labsettings_done
cat ${SETTINGSFILE}
