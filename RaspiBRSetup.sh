#!/bin/bash

# A script to setup a fresh Raspberry Pi as Thread Border Router

# Function to die with error
die() { echo "Error: " "$*" 1>&2 ; exit 1; }

INSTALL_BRANCH="master"

# Get options passed to script, such as branch ids
# First ':' is so that missing argument is reported
# 'b:' accept -b option with required argument
while getopts ":b:r:" opt; do
	case ${opt} in
	b )
		INSTALL_BRANCH=${OPTARG}
		;;
	: )
		echo "Invalid option, -${OPTARG} requires argument" 1>&2
		;;
	esac
done

# System upgrade
sudo apt update -y || die "sudo apt update"
sudo apt upgrade -y || die "sudo apt upgrade"

# Clone the install-script repo and run the BR setup script
MYDIR=$(dirname "$0")
BR_SCRIPT="${MYDIR}/_BRSetup.sh"

if [ ! -f "${BR_SCRIPT}" ]
then
	echo "Target script branch is ${INSTALL_BRANCH}"
	sudo apt install git -y || die "Installing git"

	if [ -d install-script/.git ]
	then
		git -C install-script pull || git -C install-script fetch || die "Fetching install-script"
	else
		git clone https://github.com/Cascoda/install-script.git || die "Cloning install-script"
	fi

	git -C install-script checkout "${INSTALL_BRANCH}" || die "Checking out install-script tag"

	cd install-script || die "cd"
	./_BRSetup.sh "$@"
else
	# run install script
	${BR_SCRIPT} "$@" || die "Running script"
fi
