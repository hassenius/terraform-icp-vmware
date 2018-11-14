#!/bin/bash
LOGFILE=/tmp/install-docker.log
exec  &> >(tee -a $LOGFILE)

usage() {
  echo "Usage $0 [-p <nfs/http>] [-d docker_disk]" 1>&2
  exit 1
}

while getopts ":p:d:" arg; do
    case "${arg}" in
      p)
        package_location=${OPTARG}
        ;;
      d)
        docker_disk=${OPTARG}
        ;;
    esac
done

#Find Linux Distro
if grep -q -i ubuntu /etc/*release
  then
    OSLEVEL=ubuntu
  else
    OSLEVEL=other
fi

echo "Operating System is $OSLEVEL"
echo "Package is at: ${package_location}"
echo "Docker block device is ${docker_disk}"

sourcedir=/tmp/icp-docker

# Figure out if we're asked to install at all
#if [[ -z ${package_location} ]]
#then
#  echo "Not required to install ICP provided docker. Exiting"
#  exit 0
#fi

if docker --version; then
  echo "Docker already installed. "
else
  echo "Installing docker ..."

  if [[ -z ${package_location} ]]
  # We are not providing docker binaries
  # We will install Docker from Ubuntu/Red Hat repositories.
  # Docker version: 18.03.1
  then
    # Ubuntu
    if [[ "${OSLEVEL}" == "ubuntu" ]]
    then
      # Install Docker CE from Ubuntu repositories: https://docs.docker.com/install/linux/docker-ce/ubuntu/
      # Set up the repository
      sudo apt-get update
      sudo apt-get -y install \
            apt-transport-https \
            ca-certificates \
            curl \
            software-properties-common
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      sudo add-apt-repository -y \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) \
            stable"
      # Install Docker CE
      sudo apt-get update
      sudo apt-get -y install docker-ce=18.03.1~ce-0~ubuntu
    # Red Hat
    else
      # Install Docker CE from Ubuntu repositories: https://docs.docker.com/install/linux/docker-ce/centos/
      # Set up the repository
      sudo yum install -y yum-utils \
              device-mapper-persistent-data \
              lvm2
      sudo yum-config-manager \
              --add-repo \
              https://download.docker.com/linux/centos/docker-ce.repo
      # Install Docker CE
      sudo yum install -y docker-ce-18.03.1.ce
    fi
  else
    # We are providing the Docker binaries
    mkdir -p ${sourcedir}

    # Decide which protocol to use
    if [[ "${package_location:0:3}" == "nfs" ]]
    then
      # Separate out the filename and path
      nfs_mount=$(dirname ${package_location:4})
      package_file="${sourcedir}/$(basename ${package_location})"
      # Mount
      if [[ "${OSLEVEL}" == "ubuntu" ]]
      then
        sudo apt -y install nfs-common
      else
        sudo yum -y install nfs-utils
      fi
      sudo mount.nfs $nfs_mount $sourcedir
    elif [[ "${package_location:0:4}" == "http" ]]
    then
      # Figure out what we should name the file
      filename="icp-docker.bin"
      mkdir -p ${sourcedir}
      curl -o ${sourcedir}/${filename} "${package_location#http:}"
      package_file="${sourcedir}/${filename}"
    fi

    sudo chmod a+x ${package_file}
    sudo ${package_file} --install

    if [[ "${package_location:0:3}" == "nfs" ]]
    then
      # Unmount NFS docker installer location
      sudo umount.nfs $sourcedir
    fi
  fi

  # Make sure our user is added to the docker group if needed
  # Some RHEL based installations may not have docker installed yet.
  # Only aattempt to add user to group if docker is installed and the user is not root
  if grep -q docker /etc/group
  then
    iam=$(whoami)

    if [[ $iam != "root" ]]
    then
      sudo usermod -a -G docker $iam
    fi
  fi
fi

storage_driver=`sudo docker info | grep 'Storage Driver:' | cut -d: -f2 | sed -e 's/\s//g'`
echo "storage driver is ${storage_driver}"
if [ "${storage_driver}" == "devicemapper" ]; then
  # check if loop lvm mode is enabled
  if sudo docker info | grep 'loop file'; then
    # TODO if docker block device is not provided, make sure we use overlay2 storage driver
    if [ -z "${docker_disk}" ]; then
      echo "docker loop-lvm mode is configured and a docker block device was not specified!  This is not recommended for production!"
    else
      echo "A docker disk ${docker_disk} is provided, setting up direct-lvm mode ..."

      sudo systemctl stop docker
      if [ "${OSLEVEL}" == "ubuntu" ]; then
        # on ubuntu, docker package doesn't install with devicemapper by default
        cat > /tmp/daemon.json <<EOF
{
  "storage-driver": "devicemapper",
  "storage-opts": [
    "dm.directlvm_device=${docker_disk}"
  ]
}
EOF
      else
        # docker installer uses devicemapper already
        cat > /tmp/daemon.json <<EOF
{
  "storage-opts": [
    "dm.directlvm_device=${docker_disk}"
  ]
}
EOF
      fi

      sudo mv /tmp/daemon.json /etc/docker/daemon.json
      sudo systemctl start docker
    fi
  else
    echo "Direct-lvm mode is already configured."
    exit 0
  fi
elif [ "${storage_driver}" == "overlay2" ]; then
  # Create partition for docker local images
  sudo systemctl stop docker
  /tmp/terraform_scripts/create-part.sh -p /var/lib/docker -d ${docker_disk}
  sudo systemctl start docker
fi
