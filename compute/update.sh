#!/bin/bash
#bdereims@vmware.com

for FILE in $( grep "vmware/powerclicor" *.sh | cut -f1 -d":" ); do
	echo $FILE
	sed -i "s/powerclicore:12.4/powerclicore:12.4/g" $FILE
done
