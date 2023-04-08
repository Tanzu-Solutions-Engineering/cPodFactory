<?php
$command = $_POST['command'];
$text = $_POST['text'];
$token = $_POST['token'];
$user_name = $_POST['user_name'];

require 'token.php';

if ($text != '') {
	$CPOD=explode(" ", $text);
	$STATUS = exec("./check_cpod.sh ".$CPOD[0]);
	if ($STATUS != "Ok!" ) {
		exec("nohup ./licensing_cpod.sh ".strtoupper($CPOD[0])." > nohup.out & > /dev/null");
		echo "Licensing is applied on *${CPOD[0]}*.";
	} else {
		echo ":zombie: cPod *".strtoupper($CPOD[0])."* does not exist.";
	}
} else {
	echo ":wow: Nothing to do! Name of cPod is missing.";
}
