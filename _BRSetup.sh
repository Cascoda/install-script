#!/bin/bash

# A script to setup a fresh Raspberry Pi as Thread Border Router

# Function to die with error
die() { echo "Error: " "$*" 1>&2 ; exit 1; }

OT_BR_TAG="a784a1957098be4bfd4cf3c048cb8b958f533917" #known working
SMCROUTE_TAG="f0ba8b56f7da560ccfc2d607d68d819082fed590"

# Get options passed to script, such as branch ids
# First ':' is so that missing argument is reported
# 'r:' accept -r option with required argument
while getopts ":b:r:" opt; do
	case ${opt} in
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

# First run the full install script
MYDIR=$(dirname "$0")
FULLINSTALL_SCRIPT="${MYDIR}/RaspiFullInstall.sh"
${FULLINSTALL_SCRIPT} || die "Installing cascoda-sdk"

# get build dir
MACHINE_NAME="$(uname -m)"
BUILDDIR="build-${MACHINE_NAME}"

# Stop wpantund if it is running
sudo systemctl stop wpantund.service
sudo systemctl stop hostapd.service
sudo systemctl stop dnsmasq.service

# make an install directory for the ot-ncp-posix, copy it over
CASCODA_OPT="/opt/cascoda"
NCPAPP_PATH="${CASCODA_OPT}/ot-ncp-posix"
sudo mkdir -p ${CASCODA_OPT} || die "Making install dir"
sudo cp "${BUILDDIR}/bin/ot-ncp-posix" "$NCPAPP_PATH" || sudo cp "${BUILDDIR}/bin/ncpapp" "$NCPAPP_PATH" || die "copying ot-ncp-posix"

echo "Cascoda ot-ncp-posix application installed to ${NCPAPP_PATH}."

# Install OpenThread Border Router software

# Pull if already exists, otherwise clone.
if [ -d ot-br-posix/.git ]
then
        git -C ot-br-posix remote set-url origin https://github.com/cascoda/ot-br-posix || die "Failed to set new remote URL"
        git -C ot-br-posix fetch || die "Failed to pull ot-br-posix"
else
        git clone https://github.com/cascoda/ot-br-posix ot-br-posix || die "Failed to clone ot-br-posix"
fi

git -C ot-br-posix checkout "${OT_BR_TAG}" -f || die "Failed to checkout ot-br-posix tag"

cd ot-br-posix || die "cd"
./script/bootstrap || die "Bootstrapping ot-br-posix"
NETWORK_MANAGER=0 ./script/setup || die "ot-br-posix setup"
cd ../ || die "cd"

# Actually enable the nat64 and nat44 services
TAYGA_DEFAULT="/etc/default/tayga"
sudo systemctl enable tayga
sudo systemctl enable otbr-nat44
sudo sed -i '/^RUN=/d' $TAYGA_DEFAULT
echo "RUN=\"yes\"" | sudo tee -a $TAYGA_DEFAULT > /dev/null || die "configuring tayga"

# Disable NetworkManager, as it breaks some of the manual config
sudo systemctl disable NetworkManager

# Configure DNS64 according to the available internet
DNS64_SCRIPT="${MYDIR}/_dns64_force.sh"
${DNS64_SCRIPT} || die "Configuring DNS64"

# Configure dhcpcd to not run on wlan0
DHCPCD_CONF='/etc/dhcpcd.conf'
if ! grep -q 'denyinterfaces wlan0' "${DHCPCD_CONF}"
then
	echo 'denyinterfaces wlan0' | sudo tee -a "${DHCPCD_CONF}"
fi

# Generate a ULA prefix
ULA_PREFIX=$(hexdump -n 5 -e '1/1 "fd%02x:" 2/2 "%04x:" "\n"' /dev/random)
ULA_PREFIX_SITE="${ULA_PREFIX}:"
ULA_PREFIX_WLAN="${ULA_PREFIX}1::"
ULA_PREFIX_WPAN="${ULA_PREFIX}2::"
ULA_PREFIX_ETH0="${ULA_PREFIX}3::"
SED_ULA_SUB="
s/@ULA_PREFIX_SITE@/${ULA_PREFIX_SITE}/
s/@ULA_PREFIX_WLAN@/${ULA_PREFIX_WLAN}/
s/@ULA_PREFIX_WPAN@/${ULA_PREFIX_WPAN}/
s/@ULA_PREFIX_ETH0@/${ULA_PREFIX_ETH0}/
"

# Also install hostapd for WiFi AP, and radvd for router advertisement, dnsmasq for running dhcp server
# Note: we run it twice and only check for errors the second time, as otherwise it fails by failing to start services
sudo apt install hostapd radvd dnsmasq -y
sudo apt install hostapd radvd dnsmasq -y || die "sudo apt install"

# Configure static addresses for wlan0
sudo mv /etc/network/interfaces.d/wlan0 /etc/network/interfaces.d/wlan0.bak
sudo cp "${MYDIR}/conf/wlan0" /etc/network/interfaces.d/wlan0 || die "wlan0 conf"
sudo sed -i -e "${SED_ULA_SUB}" /etc/network/interfaces.d/wlan0 || die "wlan0 sub"

# Configure hostapd
sudo mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak
sudo cp "${MYDIR}/conf/hostapd.conf" /etc/hostapd/hostapd.conf || die "hostapd conf"
sudo sed -i -e "${SED_ULA_SUB}" /etc/hostapd/hostapd.conf || die "hostapd sub"
sudo systemctl unmask hostapd.service || die "hostapd unmask"
sudo systemctl enable hostapd.service || die "hostapd enable"

# Configure dnsmasq
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
sudo cp "${MYDIR}/conf/dnsmasq.conf" /etc/dnsmasq.conf || die "dnsmasq conf"

# Configure radvd
sudo mv /etc/radvd.conf /etc/radvd.conf.bak
sudo cp "${MYDIR}/conf/radvd.conf" /etc/radvd.conf || die "radvd conf"
sudo sed -i -e "${SED_ULA_SUB}" /etc/radvd.conf || die "radvd sub"
sudo systemctl enable radvd.service

# Build smcroute, install, configure and rate-limit for multicast forwarding
# Pull if already exists, otherwise clone.
if [ -d smcroute/.git ]
then
	git -C smcroute pull || git -C smcroute fetch || die "Failed to pull smcroute"
else
	git clone https://github.com/troglobit/smcroute.git || die "Failed to clone smcroute"
fi
git -C smcroute checkout "${SMCROUTE_TAG}" || die "Failed to checkout smcroute tag"
# Build and install smcroute
cd smcroute || die "cd"
./autogen.sh
./configure --sysconfdir=/etc --runstatedir=/var/run || die "smcroute configure"
make -j4 || die "smcroute make"
sudo make install-strip || die "smcroute install"
cd ../ || die "cd"
# Configure smcroute
sudo mv /etc/smcroute.conf /etc/smcroute.conf.bak
sudo cp "${MYDIR}/conf/smcroute.conf" /etc/smcroute.conf || die "smcroute conf"
sudo systemctl enable smcroute.service || die "smcroute enable"

# Configure automatic prefix add
sudo mv /etc/ncp_state_notifier/dispatcher.d/prefix_add /etc/ncp_state_notifier/dispatcher.d/prefix_add.bak
sudo cp "${MYDIR}/conf/prefix_add" /etc/ncp_state_notifier/dispatcher.d/prefix_add || die "prefix_add conf"
sudo sed -i -e "${SED_ULA_SUB}" /etc/ncp_state_notifier/dispatcher.d/prefix_add || die "prefix_add sub"
sudo chmod a+x /etc/ncp_state_notifier/dispatcher.d/prefix_add || die "prefix_add chmod"

# Disable raspberry pi console on UART, enable uart, add required environment variable to use pi hat
sudo sed -i 's/console=serial0,115200 //g' /boot/cmdline.txt
echo "enable_uart=1" | sudo tee -a /boot/config.txt
echo "CASCODA_UART=/dev/serial0,1000000" | sudo tee -a /etc/default/wpantund

# configure our ot-ncp-posix app as the socket
WPANTUND_CONF="/etc/wpantund.conf"
if grep -Eq '^Config:NCP:SocketPath.*' ${WPANTUND_CONF}
then
	sudo sed -i '/^Config:NCP:SocketPath/d' "$WPANTUND_CONF"
fi
echo "Config:NCP:SocketPath \"system:${NCPAPP_PATH} 1\"" | sudo tee -a $WPANTUND_CONF > /dev/null || die "configuring ot-ncp-posix app"

# Add the welcome script
cp "${MYDIR}/conf/cascoda_welcome.sh" ~/.cascoda_welcome.sh
if ! grep -q "cascoda_welcome.sh" ~/.bashrc ; then
	echo "~/.cascoda_welcome.sh" >> ~/.bashrc
fi

echo ''
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '================ Cascoda Border Router Installation Complete ================'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo ''

echo "Web GUI Can be accessed in a browser on the local network with http://<ip-address>"
# Get all IP addresses with a global scope, except nat64. Use awk to format into a web address.
ip -o address show scope global | grep -v nat64 | grep inet | awk '{n=split($4,ip, "/");printf "http://%s:80\n", ip[1]}'
echo ""
echo "WiFi AP up, accessible at SSID 'Cascoda-BR' with password '12345678'"

echo ""
echo "Border Router setup complete. Please reboot the pi with 'sudo reboot' and see https://openthread.io/guides/border-router/web-gui for more info."
