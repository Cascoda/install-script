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

# Location of the named config file containing DNS64 (configured by ot-br)
NAMED_CONF="/etc/bind/named.conf.options"

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

# Change behaviour and print message depending on connectivity
if [ "$HAVE_V4" -a "$HAVE_V6" ]
then
	echo "Good! Have both IPv4 and IPv6 connectivity!"
elif [ "$HAVE_V4" ]
then
	echo "OK - Have IPv4 connectivity. IPv6 not detected, forcing DNS64"
	FORCE_DNS64=1
elif [ "$HAVE_V6" ]
then
	echo "Strange - Have IPv6 but no IPv4 connectivity, not tested!"
else
	echo "Error - No internet connectivity detected!"
	die "no internet detected"
fi

# Make sure the named config file configured by ot-br exists
if [ ! -f "$NAMED_CONF" ]
then
	die "$NAMED_CONF does not exist"
fi

# ot-br currently only seems to support NAT64, not native IPv6, so always force DNS64...
FORCE_DNS64=1

# Apply the necessary configuration, toggling between the following two lines (non-forced & forced DNS64):
# dns64 64:ff9b::/96 { clients { thread; }; recursive-only yes; };
# dns64 64:ff9b::/96 { clients { thread; }; recursive-only yes; exclude { any; }; };
if [ "$FORCE_DNS64" ]
then
	echo "Using forced DNS64"
	sudo sed -Ei 's/dns64 ([^\s]+) \{ clients \{ thread; \}; recursive-only yes; \};/dns64 \1 { clients { thread; }; recursive-only yes; exclude { any; }; };/g' $NAMED_CONF
	grep -q 'dns64.*exclude { any; }' $NAMED_CONF || die "Failed to force DNS64"
else
	echo "Using default DNS64"
	sudo sed -Ei 's/dns64 ([^\s]+) \{ clients \{ thread; \}; recursive-only yes; exclude \{ any; \}; \};/dns64 \1 { clients { thread; }; recursive-only yes; };/g' $NAMED_CONF
	grep -q 'dns64.*exclude { any; }' $NAMED_CONF && die "Failed to unforce DNS64"
fi
