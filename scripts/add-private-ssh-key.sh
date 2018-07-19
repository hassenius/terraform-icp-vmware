#!/bin/bash
user_private_key=$1
user=$2
directory="/home/${user}/ssh_keys"

if [ "$user_private_key" != "None" ] ; then
	mkdir -p $directory
    echo "$user_private_key" > $directory
    chmod 400 $directory
    ssh-add $directory

    if [[ $? -ne 0 ]]; then
    	echo "FAILED to add private ssh key"
    else
    	echo "SUCCESFULLY added private ssh key"
	fi
fi