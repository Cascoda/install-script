#!/bin/bash

# A script to setup a fresh Raspberry Pi as Thread Border Router

# Function to die with error
die() { echo "Error: " "$*" 1>&2 ; exit 1; }

INSTALL_BRANCH="master"
OT_BR_TAG="a39d800e464582cc07414ea76603ee5442ff8f89" #known working

# Get options passed to script, such as branch ids
# First ':' is so that missing argument is reported
# 'b:' accept -b option with required argument
# 'r:' accept -r option with required argument
while getopts ":b:r:" opt; do
	case ${opt} in
	b )
		INSTALL_BRANCH=${OPTARG}
		;;
	r )
		OT_BR_TAG=${OPTARG}
		;;
	\? )
		echo "Invalid option: ${opt} ${OPTARG}" 1>&2
		echo "Usage: $0 [-b <install-script branch to clone>]" 1>&2
		echo "Usage: $0 [-r <ot-br-posix tag to build>]" 1>&2
		;;
	: )
		echo "Invalid option, -${OPTARG} requires argument" 1>&2
		;;
	esac
done

# First run the full install script (download it if not found)
MYDIR=$(dirname "$0")
FULLINSTALL_SCRIPT="${MYDIR}/RaspiFullInstall.sh"

if [ ! -f "${FULLINSTALL_SCRIPT}" ]
then
	echo "Target script branch is ${INSTALL_BRANCH}"
	bash <(curl -Ls "https://raw.githubusercontent.com/Cascoda/install-script/${INSTALL_BRANCH}/RaspiFullInstall.sh") || die "Downloading and installing cascoda-sdk"
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

git -C ot-br-posix checkout ${OT_BR_TAG} || die "Failed to checkout ot-br-posix tag"

cd ot-br-posix || die "cd"
./script/bootstrap || die "Bootstrapping ot-br-posix"
NETWORK_MANAGER=0 ./script/setup || die "ot-br-posix setup"

# Actually enable the nat64 and nat44 services
TAYGA_DEFAULT="/etc/default/tayga"
sudo systemctl enable tayga
sudo systemctl enable otbr-nat44
sudo sed -i '/^RUN=/d' $TAYGA_DEFAULT
echo "RUN=\"yes\"" | sudo tee -a $TAYGA_DEFAULT > /dev/null || die "configuring tayga"

# Disable raspberry pi console on UART, enable uart, add required environment variable to use pi hat
sudo sed -i 's/console=serial0,115200 //g' /boot/cmdline.txt
echo "enable_uart=1" | sudo tee -a /boot/config.txt
echo "CASCODA_UART=/dev/serial0,1000000" | sudo tee -a /etc/default/wpantund

# configure our ncpapp as the socket
WPANTUND_CONF="/etc/wpantund.conf"
if grep -Eq '^Config:NCP:SocketPath.*' ${WPANTUND_CONF}
then
	sudo sed -i '/^Config:NCP:SocketPath/d' "$WPANTUND_CONF"
fi
echo "Config:NCP:SocketPath \"system:${NCPAPP_PATH} 1\"" | sudo tee -a $WPANTUND_CONF > /dev/null || die "configuring ncpapp"

echo "Wifi Access point set up with credentials:"
sudo nmcli -s c show BorderRouter-AP | grep -E '(wireless\.ssid:|security\.psk:)'

echo "Border Router setup complete. Please reboot the pi with 'sudo reboot' and see https://openthread.io/guides/border-router/web-gui for more info."
