#!/bin/bash

# A script to setup a fresh Raspberry Pi as Thread Border Router

# Function to die with error
die() { echo "Error: " "$*" 1>&2 ; exit 1; }

# First run the full install script (download it if not found)
MYDIR=$(dirname "$0")
FULLINSTALL_SCRIPT="${MYDIR}/RaspiFullInstall.sh"

if [ ! -f "${FULLINSTALL_SCRIPT}" ]
then
	bash <(curl -Ls https://raw.githubusercontent.com/Cascoda/install-script/master/RaspiFullInstall.sh) || die "Downloading and installing cascoda-sdk"
else
	# run install script
	${FULLINSTALL_SCRIPT} || die "Installing cascoda-sdk"
fi


# get build dir
MACHINE_NAME="$(uname -m)"
BUILDDIR="build-${MACHINE_NAME}"

# make an install directory for the ncpapp, copy it over
CASCODA_OPT="/opt/cascoda"
NCPAPP_PATH="${CASCODA_OPT}/ncpapp"
sudo mkdir -p ${CASCODA_OPT} || die "Making install dir"
sudo cp "${BUILDDIR}/bin/ncpapp" "$NCPAPP_PATH"

echo "Cascoda NCPAPP installed to ${NCPAPP_PATH}."

# Install OpenThread Border Router software

# Pull if already exists, otherwise clone.
if [ -d ot-br-posix/.git ]
then
        git -C ot-br-posix pull || die "Failed to pull ot-br-posix"
else
        git clone https://github.com/openthread/ot-br-posix ot-br-posix || die "Failed to clone ot-br-posix"
fi

cd ot-br-posix
./script/bootstrap || die "Bootstrapping ot-br-posix"
./script/setup || die "ot-br-posix setup"

# configure our ncpapp as the socket
WPANTUND_CONF="/etc/wpantund.conf"
if grep -Eq '^Config:NCP:SocketPath.*'
then
	sudo sed -i '/^Config:NCP:SocketPath/d' "$WPANTUND_CONF"
fi
echo "Config:NCP:SocketPath \"system:${NCPAPP_PATH} 1\"" | sudo tee -a $WPANTUND_CONF > /dev/null || die "configuring ncpapp"

echo "Wifi Access point set up with credentials:"
sudo nmcli -s c show BorderRouter-AP | grep -E '(wireless\.ssid:|security\.psk:)'

echo "Border Router setup complete. Please reboot the pi with 'sudo reboot' and see https://openthread.io/guides/border-router/web-gui for more info."
