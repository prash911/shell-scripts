#!/bin/bash

orb="*"
cols=`tput cols`
Black="\\033[31m"
Red="\\033[31m"
Green="\\033[32m"
Yellow="\\033[33m"
Blue="\\033[34m"
Purple="\\033[35m"
Cyan="\\033[36m"

colors="$Red	$Yellow $Green	$Blue	$Purple	$Cyan"

for rang in $colors
do
  for (( i=1; i<=$cols; i++ ))
  do
    echo "$rang$orb$White\c"
  done
  echo "\n\c"
done
