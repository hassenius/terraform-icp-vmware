#!/bin/bash

while getopts ":p:d:" arg; do
    case "${arg}" in
      p)
        path=${OPTARG}
        ;;
      d)
        device=${OPTARG}
        ;;
    esac
done

usage() {
  echo "Usage $0 [-p <path>] [-d disk]" 1>&2
  exit 1
}

if [ -z "${path}" -o -z "${device}" ]; then
  usage
fi

device_str=`echo ${device} | tr '/' '-'`

LOGFILE=/tmp/create-part${device_str}.log
exec  &> >(tee -a $LOGFILE)

#Find Linux Distro
if grep -q -i ubuntu /etc/*release
  then
    OSLEVEL=ubuntu
  else
    OSLEVEL=other
fi

echo "Operating System is $OSLEVEL"
echo "Path to mount: ${path}"
echo "Device is ${device}"

sudo mkdir -p ${path}
sudo parted -s -a optimal ${device} mklabel gpt -- mkpart primary ext4 1 -1 && sleep 10

if [ $? != 0 ]; then
  echo "Parted for ${device} failed. Please review the log file."
fi

sudo partprobe && sleep 5

sudo mkfs.ext4 ${device}1 && sleep 10

if [ $? != 0 ]; then
  echo "mkfs.ext4 for ${device}1 failed. Please review the log file."
fi

echo "${device}1 ${path}   ext4  defaults   0 0" | sudo tee -a /etc/fstab

if [[ "${OSLEVEL}" == "ubuntu" ]]
then
  sudo apt -y install nfs-common
else
  sudo yum -y install nfs-utils
fi

sudo mount -a
