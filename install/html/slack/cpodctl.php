<?php

$command = $_POST['command'];
$text = $_POST['text'];
$token = $_POST['token'];

require 'token.php';

$arguments=explode(" ", $text);
$verb = strtolower($arguments[0]);

switch ($verb) {
    case "help":
        echo "list : list all cPods\n create : create cPod [cPod_NAME] [# of ESX]\npassword : retrieve your password(s)\ndelete : delete cPod [cPod_NAME]\ndeploy_vcsa : deploy VCSA in cPod [cPod_NAME]\nadd_filer : deploy iSCSI filer [cPod_NAME]\n\n[cPod_NAME] : for example it should be MYSDDC, not cpod-mysddc\n";
        break;
    case "list":
	$reply = exec('./list_cpod.sh');
	echo $reply;
	break;
    default:
        echo "Nothing to do  here, for additionnal informations do \"/cpodctl help\".";
} 

?>
