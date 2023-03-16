<?php
$command = $_POST['command'];
$text = $_POST['text'];
$token = $_POST['token'];
$challenge = $_POST['challenge'];

#require 'token.php';
if($token != 'YsLO5DNaAiMrGy6GXEURAkkV'){
  $msg = "The token for the slash command doesn't match. Check your script.";
  die($msg);
  echo $msg;
}

exec('date +%Y/%m/%d-%H:%M:%S >> ./log'); 
exec('echo '.$token.' - '.$text.' >> ./log'); 

exec('echo launch '.$text.' >> ./log'); 
$reply = exec('./trigger_pipeline_saasV2.sh '); 
echo $reply;

/*foreach ($_POST as $name => $value) {
    $text=$name . ' : ' . $value . ', ' . $text;
}
echo $text;
*/
