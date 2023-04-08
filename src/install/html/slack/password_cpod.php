<?php

$command = $_POST['command'];
$text = $_POST['text'];
$token = $_POST['token'];
$user_name = $_POST['user_name'];

require 'token.php';

$reply = exec("./password_cpod.sh ".$user_name); 

echo $reply;

?>
