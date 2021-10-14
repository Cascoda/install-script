#!/bin/bash

# Randomize parameters if cascoda_randomize file exists
if test -f ~/.cascoda_randomize ; then
        # Stop wpantund if it is running
        sudo systemctl stop wpantund.service
        sudo systemctl stop hostapd.service
        sudo systemctl stop dnsmasq.service

        #TODO: Make MYDIR work on setups where install_script may exist elsewhere.
        MYDIR=~/install_script
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

        # Configure radvd
        sudo mv /etc/radvd.conf /etc/radvd.conf.bak
        sudo cp "${MYDIR}/conf/radvd.conf" /etc/radvd.conf || die "radvd conf"
        sudo sed -i -e "${SED_ULA_SUB}" /etc/radvd.conf || die "radvd sub"
        sudo systemctl enable radvd.service

        # Configure automatic prefix add
        sudo mv /etc/ncp_state_notifier/dispatcher.d/prefix_add /etc/ncp_state_notifier/dispatcher.d/prefix_add.bak
        sudo cp "${MYDIR}/conf/prefix_add" /etc/ncp_state_notifier/dispatcher.d/prefix_add || die "prefix_add conf"
        sudo sed -i -e "${SED_ULA_SUB}" /etc/ncp_state_notifier/dispatcher.d/prefix_add || die "prefix_add sub"
        sudo chmod a+x /etc/ncp_state_notifier/dispatcher.d/prefix_add || die "prefix_add chmod"

        # Restart services
        sudo systemctl start wpantund.service
        sudo systemctl start hostapd.service
        sudo systemctl start dnsmasq.service
        sudo systemctl restart radvd.service

        rm ~/.cascoda_randomize
fi

# Print welcome messages
echo ''
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '==================== Cascoda Thread Border Router Active ===================='
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo ''

echo "Web GUI Can be accessed in a browser on the local network with http://<ip-address>"
# Get all IP addresses with a global scope, except nat64. Use awk to format into a web address.
ip -o address show scope global | grep -v nat64 | grep inet | awk '{n=split($4,ip, "/");printf "http://%s:80\n", ip[1]}'
echo ""

WPA_PASSPHRASE=$(grep '^wpa_passphrase' /etc/hostapd/hostapd.conf | awk '{split($0,a,"="); print a[2]}')
AP_SSID=$(grep '^ssid' /etc/hostapd/hostapd.conf | awk '{split($0,a,"="); print a[2]}')

if systemctl is-active --quiet hostapd.service
then
        # wifi ap is up, print details
        printf 'WiFi AP is up! SSID: \"%s\", Password: \"%s\"\n' "${AP_SSID}" "${WPA_PASSPHRASE}"
else
        # wifi ap is down
        echo "WiFi AP is down. See the systemctl hostapd.service to re-enable"
fi

echo "For quick start guide, visit https://github.com/Cascoda/cascoda-sdk/blob/master/docs/how-to/howto-thread.md"

