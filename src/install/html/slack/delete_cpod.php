<?php

$command = $_POST['command'];
$text = $_POST['text'];
$token = $_POST['token'];
$user_name = $_POST['user_name'];

require 'token.php';

if ($text != '') {
	$CPOD=explode(" ", $text);
        $NAME = strtoupper($CPOD[0]);
        if (strpos($NAME,"CPOD") !== false) {
                $msg = ":thumbsdown: Name should not contains ".$CPOD[0].".";
                die($msg);
        }
	$STATUS = exec("./check_cpod.sh ".$CPOD[0]);
	if ($STATUS == "Ok!" ) {
		echo ":zombie: ".$CPOD[0]." does not exist!";
	} else {
		exec("nohup ./delete_cpod.sh ".strtoupper($CPOD[0])." ".$user_name." > nohup.out & > /dev/null");
	}
} else {
	$reply = exec("./list_cpod.sh ".$user_name); 
	echo "You're owner of: ".$reply;
}

?>
