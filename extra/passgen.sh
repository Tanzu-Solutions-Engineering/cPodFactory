#!/bin/bash

pwgen -s -N 1 -n -c -y 10 | sed -e 's/\\/!/' -e 's/;/-/' -e 's/"/$/'
