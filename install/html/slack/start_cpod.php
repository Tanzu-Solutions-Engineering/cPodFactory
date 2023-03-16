<?php

$command = $_POST['command'];
$text = $_POST['text'];
$token = $_POST['token'];

require 'token.php';

$reply = exec('./start_cpod.sh'); 

echo $reply;

?>
