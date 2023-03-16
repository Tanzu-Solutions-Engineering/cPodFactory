#!/bin/bash
#bdereims@vmware.com

ps -ef | grep root@pts | awk '{print $2}' | xargs kill
