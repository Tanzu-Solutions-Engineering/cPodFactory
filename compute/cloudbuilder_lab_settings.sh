#!/bin/bash
#edewitte@vmware.com
# Script to be executed on cloudbuilder via vmtools remote exec.

[ -f /home/admin/labsettings_done ] && echo "Lab settings already set" && exit 

echo "#Lab sizing entries" >>/etc/vmware/vcf/domainmanager/application-prod.properties
echo "nsxt.manager.formfactor=small" >>/etc/vmware/vcf/domainmanager/application-prod.properties
echo "nsxt.manager.wait.minutes=45" >>/etc/vmware/vcf/domainmanager/application-prod.properties
echo "nsxt.manager.cluster.size=1" >>/etc/vmware/vcf/domainmanager/application-prod.properties
echo "nsxt.management.resources.validation.skip=true" >>/etc/vmware/vcf/domainmanager/application-prod.properties
echo "vc7.deployment.option:small" >>/etc/vmware/vcf/domainmanager/application-prod.properties

systemctl restart domainmanager
touch /home/admin/labsettings_done
