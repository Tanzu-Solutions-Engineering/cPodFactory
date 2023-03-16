<?php

$command = $_POST['command'];
$text = $_POST['text'];
$token = $_POST['token'];

require 'token.php';

/*
$reply = ":thumbsup:".exec('cat /etc/hosts | cut -f2 | grep "cpod-" | sed "s/cpod-//" | tr [:lower:] [:upper:] | sed ':a;N;$!ba;s/\n/ /g'');
*/
$reply = exec('./wiki_cpod.sh'); 

echo $reply;

?>
