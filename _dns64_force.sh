#!/bin/bash

# A script to detect if we have ipv4 and not ipv6 connectivity, and configure DNS64 accordingly.
# If we only have IPv4 internet access, we synthesize all DNS AAAA responses to be NAT64 addresses.
# If we have both, then we use the normal DNS64 where only missing AAAA responses are synthesized.

# Function to die with error
die() { echo "Error: " "$*" 1>&2 ; exit 1; }

# Define well known addresses with IPv4 and IPv6 addresses
ADDR1=cloudflare.com
ADDR2=google.com
ADDR3=google.cn

# Argument sets for ping v4 and v6 
PV4ARG="-4 -c2"
PV6ARG="-6 -c2"

# Detect IPv4 connectivity
if { ping $PV4ARG $ADDR1 || ping $PV4ARG $ADDR2 || ping $PV4ARG $ADDR3 ; } 1>&2
then
	HAVE_V4=1
fi

# Detect IPv6 connectivity
if { ping $PV6ARG $ADDR1 || ping $PV6ARG $ADDR2 || ping $PV6ARG $ADDR3 ; } 1>&2
then
	HAVE_V6=1
fi

if [ "$HAVE_V4" -a "$HAVE_V6" ]
then
	echo "Good! Have both IPv4 and IPv6 connectivity!"
elif [ "$HAVE_V4" ]
then
	echo "OK - Have IPv4 connectivity. IPv6 not detected, forcing DNS64"
elif [ "$HAVE_V6" ]
then
	echo "Strange - Have IPv6 but no IPv4 connectivity, not tested!"
else
	echo "Error - No internet connectivity detected!"
fi
