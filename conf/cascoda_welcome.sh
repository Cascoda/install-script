#!/bin/bash

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

