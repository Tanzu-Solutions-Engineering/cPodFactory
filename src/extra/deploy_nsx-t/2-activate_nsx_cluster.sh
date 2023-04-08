#!/bin/bash -e

source ./install_nsx.env

function configure_nsx_cluster() {

  local manager_ip=$NSX_MANAGER_IP
  local manager_password=${NSX_MANAGER_PASSWORD:=$NSX_COMMON_PASSWORD}
  local controller_ip=$NSX_CONTROLLER_IP
  local controller_password=${NSX_CONTROLLER_PASSWORD:=$NSX_COMMON_PASSWORD}
  local edge_ip=$NSX_EDGE_IP
  local edge_password=${NSX_EDGE_PASSWORD:=$NSX_COMMON_PASSWORD}

  sed -i -e "/^$manager_ip/ d" ~/.ssh/known_hosts || true
  sed -i -e "/^$controller_ip/ d" ~/.ssh/known_hosts || true
  sed -i -e "/^$edge_ip/ d" ~/.ssh/known_hosts || true

  echo "Get NSX manager thumbprint"
  local manager_thumbprint=`eval sshpass -p $manager_password ssh -o StrictHostKeyChecking=no root@$manager_ip "/opt/vmware/nsx-cli/bin/scripts/nsxcli -c \"get certificate api thumbprint\""`

  echo "Join NSX controller to management plane"
  eval sshpass -p $controller_password ssh root@$controller_ip -o StrictHostKeyChecking=no "/opt/vmware/nsx-cli/bin/scripts/nsxcli -c \"join management-plane $manager_ip username admin thumbprint $manager_thumbprint password $manager_password\""
  eval sshpass -p $controller_password ssh root@$controller_ip -o StrictHostKeyChecking=no "/opt/vmware/nsx-cli/bin/scripts/nsxcli -c \"set control-cluster security-model shared-secret secret $controller_password\""
  eval sshpass -p $controller_password ssh root@$controller_ip -o StrictHostKeyChecking=no "/opt/vmware/nsx-cli/bin/scripts/nsxcli -c \"initialize control-cluster\""

  echo "Join NSX edge to management plane"
  eval sshpass -p $edge_password ssh root@$edge_ip -o StrictHostKeyChecking=no "/opt/vmware/nsx-cli/bin/scripts/nsxcli -c \"join management-plane $manager_ip username admin thumbprint $manager_thumbprint password $manager_password\""
}


######################################################
#						     #
#   Main Script					     #
#						     #
######################################################


echo ""
echo "Activate NSX cluster"
echo ""

configure_nsx_cluster


echo ""
echo "OPERATION COMPLETED: Activate NSX cluster"
echo ""
