#!/bin/bash
#edewitte@vmware.com

source ./env
source ./govc_env
source ./compute/cpod-xxx_env
source ./extra/functions.sh


echo "enter name for new cpod version file (vspherexxx.sh)"
read filename

cat << EOF > ${filename}
#!/bin/bash
#edewitte@vmware.com

# source this env file and
# create cPod with: cpodctl create X 3 [you-name]

EOF

# select ESX template
echo 
echo "Select ESX Template"
echo

TEMPLATES=$(govc ls /${VCENTER_DATACENTER}/vm/${TEMPLATE_FOLDER} |grep ESX | rev | cut -d"/" -f1 |rev )
TEMPLATES=${TEMPLATES}" Quit"

select TEMPLATE in ${TEMPLATES}; do 
    if [ "${TEMPLATE}" = "Quit" ]; then 
      exit
    fi
    echo "you selected version : ${TEMPLATE}"
	  echo "export TEMPLATE_ESX=${TEMPLATE}" >> ${filename}
    break
done

# select VCSA OVA 
echo 
echo "Select Cloudbuilder OVA"
echo
 
OVAS=$(ls ${BITS}/VMware-Cloud-Builder-*)
OVAS=${OVAS}" None"

select OVA in ${OVAS}; do 
    if [ "${OVA}" = "None" ]; then 
      exit
    fi
    echo "you selected version : ${OVA}"
	  echo "export OVA_CLOUDBUILDER=${OVA}" >> ${filename}
    break
done

VCF_VERSION=$(echo "${OVA}" |sed 's/.*\///' | sed 's/VMware-Cloud-Builder-//'  | cut -d "." -f1)

echo 
echo "Select JSON template"
echo

JSONS=$(ls ./compute/cloudbuilder-*.json | rev | cut -d "/" -f1 | rev)
JSONS=${JSONS}" None"

select JSON in ${JSONS}; do 
    if [ "${JSON}" = "None" ]; then 
      break
    fi
    echo "you selected version : ${JSON}"
	  echo "export JSON_TEMPLATE=${JSON}" >> ${filename}
	  echo "export EMS_TEMPLATE=${JSON}" >> ${filename}
    break
done

echo "export NOCUSTO='YES'" >> ${filename}

#get licenses

apply_license(){
  echo "export LIC_ESX=${ESX_KEY}" >> ${filename}
  echo "export LIC_VCSA=${VCENTER_KEY}" >> ${filename}
  echo "export LIC_VSAN=${VSAN_KEY}" >> ${filename}
  echo "export LIC_NSXT=${LIC_NSXT}" >> ${filename}
}

case $VCF_VERSION in
	4)
		check_license_file "V7"
		echo "Applying Version 7"
		VCENTER_KEY=$V7_VCENTER_KEY
		ESX_KEY=$V7_ESX_KEY
		VSAN_KEY=$V7_VSAN_KEY
		#NSXT_KEY
    apply_license
		;;
	5)
		check_license_file "V8"
		echo "Applying Version 8"
		VCENTER_KEY=$V8_VCENTER_KEY
		ESX_KEY=$V8_ESX_KEY
		VSAN_KEY=$V8_VSAN_KEY
    #NSXT_KEY
    apply_license
		;;
	*)
		echo "Version $VCF_VERSION not foreseen yet by script"
		;;
esac

echo
echo "Done"
cat ${filename}