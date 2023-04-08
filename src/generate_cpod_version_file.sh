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

export NOCUSTO='NO' # =NO means configure nfsdatastore based on cpodrouter
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
echo "Select vCenter OVA"
echo
 
OVAS=$(ls ${BITS}/VMware-vCenter-Server*)
OVAS=${OVAS}" None"

select OVA in ${OVAS}; do 
    if [ "${OVA}" = "None" ]; then 
      exit
    fi
    echo "you selected version : ${OVA}"
	  echo "export OVA_VCSA=${OVA}" >> ${filename}
    break
done


echo 
echo "Select NSX OVA"
echo

OVAS=$(ls ${BITS}/nsx*)
OVAS=${OVAS}" None"

select OVA in ${OVAS}; do 
    if [ "${OVA}" = "None" ]; then 
      break
    fi
    echo "you selected version : ${OVA}"
	  echo "export OVA_NSXMGR=${OVA}" >> ${filename}
    break
done


echo 
echo "Select NSX ALB OVA"
echo

OVAS=$(ls ${BITS}/controller*)
OVAS=${OVAS}" None"

select OVA in ${OVAS}; do 
    if [ "${OVA}" = "None" ]; then 
      break
    fi
    echo "you selected version : ${OVA}"
	  echo "export NSXALBOVA=${OVA}" >> ${filename}
    break
done


echo 
echo "Select SIVT OVA"
echo

OVAS=$(ls ${BITS}/service-installer-*)
OVAS=${OVAS}" None"

select OVA in ${OVAS}; do 
    if [ "${OVA}" = "None" ]; then 
      break
    fi
    echo "you selected version : ${OVA}"
	  echo "export OVA_SIVT=${OVA}" >> ${filename}
    break
done

echo "================================"
echo "= Done - filename:  "${filename}
echo "================================"
echo

cat ${filename}