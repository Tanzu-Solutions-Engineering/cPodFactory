#!/bin/bash
#bdereims@gmail.com

tail -n $(echo $RANDOM %1179 | bc) ~/cPodFactory/extra/ikea.names | head -1
