#!/bin/bash
user_public_key=$1
if [ "$user_public_key" != "None" ] ; then
    echo "$user_public_key" >> $HOME/.ssh/authorized_keys

    if [[ $? -ne 0 ]]; then
    	echo "FAILED to add public ssh key"
    else
    	echo "SUCCESFULLY added public ssh key"
	fi
fi